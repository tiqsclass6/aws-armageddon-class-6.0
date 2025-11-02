import os
from flask import Flask, render_template, url_for

app = Flask(__name__)

@app.route("/")
def home():
    artist = {
        "name": 'Snoop Dogg "Snoop Doggy Dogg"',
        "platinum_albums": "4× Platinum (Doggystyle) + multiple multi-platinum",
        "most_notable": "Doggystyle (4× Platinum)",
        "hero_image": url_for("static", filename="app3.jpg"),
    }
    return render_template("index.html", artist=artist, bg_class="app3")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8083))
    app.run(host="0.0.0.0", port=port)
