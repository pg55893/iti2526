import os
from flask import Flask, request, render_template_string, send_from_directory, redirect, session, url_for
from flask_bcrypt import Bcrypt
from flasgger import Swagger

UPLOAD_FOLDER = "/home/umdrive/uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
swagger = Swagger(app)
app.secret_key = "C87A55AA7182A34B9A4FCF3FFE1E9"
bcrypt = Bcrypt(app)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Utilizador Default
USERNAME = "admin"
PASSWORD_HASH = bcrypt.generate_password_hash("1234").decode("utf-8")

HTML_LOGIN = """
<h2>Login</h2>
<form method="post">
  <input type="text" name="username" placeholder="Utilizador"><br>
  <input type="password" name="password" placeholder="Password"><br>
  <button type="submit">Entrar</button>
</form>
"""

HTML_FILES = """
<h2>UM Drive</h2>
<p>Autenticado como {{ user }} | <a href="/logout">Logout</a></p>
<form action="/upload" method="post" enctype="multipart/form-data">
  <input type="file" name="file">
  <button type="submit">Upload</button>
</form>
<ul>
{% for f in files %}
  <li>
    {{ f }} - 
    <a href="/files/{{ f }}">Ver</a> | 
    <a href="/delete/{{ f }}">Apagar</a>
  </li>
{% endfor %}
</ul>
"""

def login_required(func):
    def wrapper(*args, **kwargs):
        if not session.get("logged_in"):
            return redirect(url_for("login"))
        return func(*args, **kwargs)
    wrapper.__name__ = func.__name__
    return wrapper

@app.route("/login", methods=["GET", "POST"])
def login():
    """Autenticação de utilizadores
    ---
    post:
      summary: Faz login de um utilizador
      description: Permite autenticar um utilizador com username e password.
      consumes:
        - application/x-www-form-urlencoded
      parameters:
        - name: username
          in: formData
          type: string
          required: true
          description: Nome de utilizador
        - name: password
          in: formData
          type: string
          required: true
          description: Palavra-passe
      responses:
        302:
          description: Redireciona para a página inicial em caso de sucesso
        200:
          description: Mostra o formulário de login se for um pedido GET
    """
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]

        if username == USERNAME and bcrypt.check_password_hash(PASSWORD_HASH, password):
            session["logged_in"] = True
            session["username"] = username
            return redirect("/")
    return render_template_string(HTML_LOGIN)

@app.route("/logout")
def logout():
    """Logout do utilizador
    ---
    get:
      summary: Termina a sessão de um utilizador
      description: Limpa a sessão e redireciona para a página de login.
      responses:
        302:
          description: Redireciona para /login após terminar a sessão
    """
    session.clear()
    return redirect("/login")

@login_required
@app.route("/")
def index():
    """Listagem de ficheiros
    ---
    get:
      summary: Mostra a lista de ficheiros disponíveis
      description: Retorna uma página HTML com os ficheiros no diretório de uploads.
      responses:
        200:
          description: Página HTML com a lista de ficheiros
    """
    files = os.listdir(UPLOAD_FOLDER)
    return render_template_string(HTML_FILES, files=files, user=session.get("username"))

@login_required
@app.route("/upload", methods=["POST"])
def upload():
    """Upload de ficheiros
    ---
    post:
      summary: Faz upload de um ficheiro
      description: Recebe um ficheiro através de formulário e guarda-o no servidor.
      consumes:
        - multipart/form-data
      parameters:
        - name: file
          in: formData
          type: file
          required: true
          description: Ficheiro a carregar
      responses:
        302:
          description: Redireciona para a página inicial após o upload
    """
    file = request.files['file']
    if file:
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], file.filename))
    return redirect("/")

@login_required
@app.route("/files/<filename>")
def serve_file(filename):
    """Download de ficheiro
    ---
    get:
      summary: Faz download de um ficheiro
      description: Retorna o ficheiro solicitado se existir no diretório de uploads.
      parameters:
        - name: filename
          in: path
          type: string
          required: true
          description: Nome do ficheiro
      responses:
        200:
          description: Ficheiro retornado com sucesso
        404:
          description: Ficheiro não encontrado
    """
    return send_from_directory(UPLOAD_FOLDER, filename)

@login_required
@app.route("/delete/<filename>")
def delete_file(filename):
    """Eliminação de ficheiro
    ---
    get:
      summary: Apaga um ficheiro do servidor
      description: Remove o ficheiro indicado e redireciona para a página inicial.
      parameters:
        - name: filename
          in: path
          type: string
          required: true
          description: Nome do ficheiro a apagar
      responses:
        302:
          description: Redireciona para a página principal após apagar o ficheiro
    """
    os.remove(os.path.join(UPLOAD_FOLDER, filename))
    return redirect("/")
    
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

