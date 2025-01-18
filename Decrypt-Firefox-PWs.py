import json
import base64
import sqlite3
from os import path
from getpass import getpass
from Cryptodome.Cipher import AES
from Cryptodome.Protocol.KDF import PBKDF2
from Cryptodome.Util.Padding import unpad

def get_key_from_db(db_path, master_password=''):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT item1, item2 FROM metadata WHERE id = 'password';")
    row = cursor.fetchone()
    global_salt = row[0]
    item2 = row[1]
    conn.close()

    decoded_item2 = base64.b64decode(item2)
    entry_salt_length = decoded_item2[1]
    entry_salt = decoded_item2[4:4 + entry_salt_length]
    cipher_text = decoded_item2[4 + entry_salt_length:]

    key = PBKDF2(master_password, global_salt, dkLen=32, count=1)
    cipher = AES.new(key, AES.MODE_CBC, entry_salt)
    decrypted = unpad(cipher.decrypt(cipher_text), AES.block_size)
    return decrypted[:32]

def decrypt_password(ciphertext, key):
    iv = ciphertext[:16]
    payload = ciphertext[16:]
    cipher = AES.new(key, AES.MODE_CBC, iv)
    decrypted = unpad(cipher.decrypt(payload), AES.block_size)
    return decrypted.decode('utf-8')

def decrypt_firefox_passwords(logins_path, key4db_path, master_password=''):
    key = get_key_from_db(key4db_path, master_password)
    
    with open(logins_path, 'r') as f:
        logins_data = json.load(f)
    
    passwords = []
    for login in logins_data['logins']:
        ciphertext = base64.b64decode(login['encryptedPassword'])
        password = decrypt_password(ciphertext, key)
        
        passwords.append({
            'url': login['hostname'],
            'username': login['encryptedUsername'],
            'password': password
        })
    
    return passwords

if __name__ == '__main__':
    import argparse
    import os

    # Holen Sie sich das Verzeichnis, in dem das Skript ausgeführt wird
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Standardpfade für logins.json und key4.db im selben Verzeichnis wie das Skript
    default_logins_path = path.join(script_dir, 'logins.json')
    default_key4db_path = path.join(script_dir, 'key4.db')
    output_file_path = path.join(script_dir, 'decrypted_passwords.txt')

    parser = argparse.ArgumentParser(description='Decrypt Firefox passwords')
    parser.add_argument('-l', '--logins', default=default_logins_path, help='Path to logins.json')
    parser.add_argument('-k', '--keydb', default=default_key4db_path, help='Path to key4.db')
    parser.add_argument('-p', '--password', required=False, help='Master password', default='')

    args = parser.parse_args()

    passwords = decrypt_firefox_passwords(args.logins, args.keydb, args.password)
    
    with open(output_file_path, 'w') as f:
        for p in passwords:
            f.write(f"URL: {p['url']}, Username: {p['username']}, Password: {p['password']}\n")
    
    print(f"Decrypted passwords have been saved to {output_file_path}")
