import os
from flask import Flask, render_template, url_for

# Get directory containing this file (app3.py)
basedir = os.path.abspath(os.path.dirname(__file__))

app = Flask(
    __name__,
    static_folder=os.path.join(basedir, 'static'),     # points to apps/app3/static/
    static_url_path='/app3/static'                     # keeps URL prefix consistent with path
)

@app.route("/health")
def health():
    return "OK", 200

@app.route("/app3")
def home():
    artist = {
        "name": 'Snoop Dogg "Snoop Doggy Dogg"',
        "platinum_albums": "4× Platinum (Doggystyle) + multiple multi-platinum",
        "most_notable": "Doggystyle (4× Platinum)",
        "hero_image": url_for("static", filename="app3.jpg"),  # no leading /static/
    }
    return render_template("index.html", artist=artist, bg_class="app3")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8083))
    app.run(host="0.0.0.0", port=port)