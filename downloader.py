import os
import sys
import json
import subprocess
import shutil
import threading # Vamos precisar disso para não travar a interface
from pathlib import Path
import webview
import requests
from flask import Flask, send_file, jsonify, request

# Configuração
if getattr(sys, 'frozen', False):
    # Se for o executável, a pasta base é a temporária (_MEIxxxxx)
    BASE_DIR = Path(sys._MEIPASS)
else:
    # Se estiver rodando o código normal (python downloader.py)
    BASE_DIR = Path(__file__).parent

STATUS_FILE = BASE_DIR / 'status.txt'
# Criar Flask app
app = Flask(__name__, static_folder='.', static_url_path='')

def read_status():
    """Lê o arquivo status.txt e retorna um dicionário"""
    status_dict = {}
    if STATUS_FILE.exists():
        with open(STATUS_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if ' - ' in line:
                    parts = line.split(' - ')
                    if len(parts) == 2:
                        name = parts[0].strip().lower()
                        status = parts[1].strip().lower()
                        status_dict[name] = status
    return status_dict

def get_file_status(filename):
    """Retorna o status de um arquivo baseado no status.txt"""
    status_dict = read_status()
    # Remove extensão para comparar
    name_without_ext = Path(filename).stem.lower()
    return status_dict.get(name_without_ext, 'unknown')

@app.route('/')
def index():
    return send_file('index.html')

@app.route('/api/executors')
def list_executors():
    """Lista todos os executores na pasta executors/"""
    executors = []
    exec_dir = BASE_DIR / 'executors'
    
    if exec_dir.exists():
        for file in exec_dir.iterdir():
            if file.is_file() and file.suffix.lower() in ['.exe', '.msi']:
                status = get_file_status(file.name)
                executors.append({
                    'name': file.name,
                    'path': f'executors/{file.name}',
                    'size': format_size(file.stat().st_size),
                    'status': status,
                    'emoji': '⚡'
                })
    
    return jsonify(executors)

@app.route('/api/scripts')
def list_scripts():
    """Lista todos os scripts na pasta scripts/"""
    scripts = []
    script_dir = BASE_DIR / 'scripts'
    
    if script_dir.exists():
        for file in script_dir.iterdir():
            if file.is_file() and file.suffix.lower() in ['.lua', '.py', '.js', '.txt']:
                scripts.append({
                    'name': file.name,
                    'path': f'scripts/{file.name}',
                    'size': format_size(file.stat().st_size),
                    'emoji': '📜'
                })
    
    return jsonify(scripts)

@app.route('/run/<path:filename>')
def run_file(filename):
    file_path = BASE_DIR / filename
    
    if not file_path.exists():
        return jsonify({'success': False, 'message': 'Arquivo não encontrado'})
    
    try:
        if filename.lower().endswith('.exe'):
            # O SEGREDO ESTÁ AQUI:
            # 1. cwd=str(file_path.parent) -> Garante que o .exe vai rodar dentro da própria pasta onde ele está (evita erro de DLL/Bootstrapper)
            # 2. shell=True -> Usa o terminal do Windows
            # 3. 'start' -> Comando nativo do Windows que "solta" o programa. Mesmo que o programa feche sozinho, o Python não vai ser afetado.
            subprocess.Popen(f'start "" "{file_path}"', shell=True, cwd=str(file_path.parent))
            
            return jsonify({'success': True, 'message': f'{file_path.name} iniciado com sucesso!'})
        else:
            return jsonify({'success': False, 'message': 'Tipo de arquivo não suportado para execução'})
    except Exception as e:
        return jsonify({'success': False, 'message': f'Erro: {str(e)}'})
@app.route('/download/<path:filename>')
def download_file(filename):
    """Baixa um arquivo para a pasta Downloads do usuário"""
    file_path = BASE_DIR / filename
    if not file_path.exists():
        return jsonify({'success': False, 'message': 'Arquivo não encontrado'}), 404
    
    try:
        # 1. Descobre a pasta Downloads do Windows
        downloads_path = os.path.join(os.path.expanduser("~"), "Downloads")
        
        # 2. Define o destino final
        destination = os.path.join(downloads_path, os.path.basename(filename))
        
        # 3. Faz a cópia do arquivo (se já existir com o mesmo nome, sobrescreve ou renomeia automaticamente)
        shutil.copy2(file_path, destination)
        
        # 4. Retorna sucesso pro frontend
        return jsonify({
            'success': True, 
            'message': f'Arquivo salvo em: {destination}'
        })
    except Exception as e:
        return jsonify({'success': False, 'message': f'Erro ao baixar: {str(e)}'}), 500

@app.route('/view/<path:filename>')
def view_file(filename):
    """Visualiza o conteúdo de um script"""
    file_path = BASE_DIR / filename
    if not file_path.exists():
        return jsonify({'success': False, 'message': 'Arquivo não encontrado'}), 404
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        return content
    except:
        return jsonify({'success': False, 'message': 'Não é possível ler este arquivo como texto'}), 400

def format_size(size_bytes):
    """Formata o tamanho do arquivo"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024:
            return f'{size_bytes:.1f} {unit}'
        size_bytes /= 1024
    return f'{size_bytes:.1f} TB'

def create_status_example():
    """Cria um arquivo status.txt de exemplo se não existir"""
    if not STATUS_FILE.exists():
        with open(STATUS_FILE, 'w', encoding='utf-8') as f:
            f.write("madium - broken\n")
            f.write("solara - working\n")
            f.write("xeno - updating\n")

def main():
    """Função principal que inicia o aplicativo"""
    # Criar pastas necessárias
    (BASE_DIR / 'executors').mkdir(exist_ok=True)
    (BASE_DIR / 'scripts').mkdir(exist_ok=True)
    
    # Criar status.txt de exemplo
    create_status_example()
    
    # Iniciar o servidor Flask em uma thread separada
    from threading import Thread
    def run_flask():
        app.run(host='127.0.0.1', port=5000, debug=False)
    
    Thread(target=run_flask, daemon=True).start()
    
    # Iniciar a janela com pywebview
    webview.create_window(
        '📦 Downloader de Lixos',
        'http://127.0.0.1:5000',
        width=1100,
        height=750,
        resizable=True,
        min_size=(800, 600)
    )
    webview.start()

if __name__ == '__main__':
    # Verificar se pywebview está instalado
    try:
        import webview
    except ImportError:
        print('📦 Instalando pywebview...')
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'pywebview'])
        import webview
    
    # Verificar se flask está instalado
    try:
        import flask
    except ImportError:
        print('📦 Instalando Flask...')
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'flask'])
        import flask
    
    main()