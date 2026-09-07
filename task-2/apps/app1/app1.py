import os
from flask import Flask, render_template, url_for

# Get the directory containing app1.py
basedir = os.path.abspath(os.path.dirname(__file__))

app = Flask(
    __name__,
    static_folder=os.path.join(basedir, 'static'),          # ← point to nested static
    static_url_path='/app1/static'                          # ← optional: keep URL clean
)

@app.route("/health")
def health():
    return "OK", 200   # Simple static response; can later add real checks (db, etc.)

@app.route("/app1")
def home():
    artist = {
        "name": 'Tupac Shakur "2-Pac"',
        "platinum_albums": "Ten (10)",
        "most_notable": "All Eyez On Me (Certified Diamond)",
        "hero_image": url_for("static", filename="app1.jpg"),  # no /static/ prefix needed
    }
    return render_template("index.html", artist=artist, bg_class="app1")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8081))
    app.run(host="0.0.0.0", port=port)