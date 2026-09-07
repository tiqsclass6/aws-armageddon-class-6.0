import os
from flask import Flask, render_template, url_for

# Get directory containing this file (app2.py)
basedir = os.path.abspath(os.path.dirname(__file__))

app = Flask(
    __name__,
    static_folder=os.path.join(basedir, 'static'),     # points to apps/app2/static/
    static_url_path='/app2/static'                     # keeps URL prefix consistent with path
)

@app.route("/health")
def health():
    return "OK", 200   # Simple static response; can later add real checks (db, etc.)

@app.route("/app2")
def home():
    artist = {
        "name": 'Dr. Dre',
        "platinum_albums": "Multiple Platinum / 6x Platinum-era producer",
        "most_notable": "The Chronic (3× Platinum)",
        "hero_image": url_for("static", filename="app2.jpg"),  # no leading /static/
    }
    return render_template("index.html", artist=artist, bg_class="app2")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8082))
    app.run(host="0.0.0.0", port=port)