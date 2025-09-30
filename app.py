import os
from flask import Flask, request, render_template_string, send_from_directory, redirect, session, url_for
from flask_bcrypt import Bcrypt

UPLOAD_FOLDER = "/home/umdrive/uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
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
    session.clear()
    return redirect("/login")

@app.route("/")
@login_required
def index():
    files = os.listdir(UPLOAD_FOLDER)
    return render_template_string(HTML_FILES, files=files, user=session.get("username"))

@app.route("/upload", methods=["POST"])
@login_required
def upload():
    file = request.files['file']
    if file:
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], file.filename))
    return redirect("/")

@app.route("/files/<filename>")
@login_required
def serve_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route("/delete/<filename>")
@login_required
def delete_file(filename):
    os.remove(os.path.join(UPLOAD_FOLDER, filename))
    return redirect("/")
    
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

