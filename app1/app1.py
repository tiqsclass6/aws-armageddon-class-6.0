import os
from flask import Flask, render_template, url_for

app = Flask(__name__)

@app.route("/")
def home():
    artist = {
        "name": 'Tupac Shakur "2-Pac"',
        "platinum_albums": "Ten (10)",
        "most_notable": "All Eyez On Me (Certified Diamond)",
        "hero_image": url_for("static", filename="app1.jpg"),  # put app1.jpg in app1/static/
    }
    return render_template("index.html", artist=artist, bg_class="app1")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8081))
    app.run(host="0.0.0.0", port=port)
