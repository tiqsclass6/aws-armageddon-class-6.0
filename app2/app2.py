import os
from flask import Flask, render_template, url_for

app = Flask(__name__)

@app.route("/")
def home():
    artist = {
        "name": 'Dr. Dre',
        "platinum_albums": "Multiple Platinum / 6x Platinum-era producer",
        "most_notable": "The Chronic (3× Platinum)",
        "hero_image": url_for("static", filename="app2.jpg"),
    }
    return render_template("index.html", artist=artist, bg_class="app2")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8082))
    app.run(host="0.0.0.0", port=port)
