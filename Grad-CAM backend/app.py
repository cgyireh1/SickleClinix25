import os
import uuid
import base64
import numpy as np
from flask import Flask, request, jsonify
from tensorflow.keras.models import load_model
import cv2
from utils.gradcam_utils import make_gradcam_heatmap

# === Configuration ===
UPLOAD_FOLDER = 'uploads'
HEATMAP_FOLDER = os.path.join('static', 'heatmaps')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(HEATMAP_FOLDER, exist_ok=True)

# === Flask App ===
app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# === Load Model ===
model = load_model('model/mobilenetv2_best_model_16.keras')
input_size = (224, 224)

print("Warming up model...")
dummy_input = np.zeros((1, *input_size, 3), dtype=np.float32)
model.predict(dummy_input)
print("Model ready")

@app.route('/')
def home():
    return 'Welcome To SickleClinix !'

@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    image_file = request.files['image']
    image_id = str(uuid.uuid4())
    image_path = os.path.join(UPLOAD_FOLDER, image_id + '.jpg')
    image_file.save(image_path)

    try:
        # === Preprocess Image ===
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError("Could not read uploaded image.")

        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img = cv2.resize(img, input_size)
        img_array = img.astype(np.float32) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        # === Predict ===
        pred = model.predict(img_array, verbose=0)[0][0]
        label = "Sickle" if pred > 0.5 else "Normal"
        confidence = float(pred) if pred > 0.5 else 1 - float(pred)

        # === Grad-CAM ===
        heatmap = make_gradcam_heatmap(img_array, model)
        heatmap = cv2.resize(heatmap, input_size)
        heatmap = np.uint8(255 * heatmap)
        heatmap_color = cv2.applyColorMap(heatmap, cv2.COLORMAP_JET)

        original = cv2.imread(image_path)
        if original is None:
            raise ValueError("Could not reload image for Grad-CAM.")
        original = cv2.resize(original, input_size)

        superimposed = cv2.addWeighted(original, 0.6, heatmap_color, 0.4, 0)

        # === Save Heatmap to Static Folder ===
        heatmap_filename = image_id + '_heatmap.jpg'
        heatmap_path = os.path.join(HEATMAP_FOLDER, heatmap_filename)
        cv2.imwrite(heatmap_path, superimposed)

        # === Debug print ===
        print(f"[INFO] Heatmap saved to: {heatmap_path}")
        print(f"[INFO] Exists? {os.path.exists(heatmap_path)}")

        # === Return base64 ===
        with open(heatmap_path, 'rb') as f:
            encoded_image = base64.b64encode(f.read()).decode('utf-8')

        # os.remove(image_path)

        return jsonify({
            'label': label,
            'confidence': round(confidence, 4),
            'heatmap_base64': encoded_image,
            'heatmap_file': heatmap_path
        })

    except Exception as e:
        if os.path.exists(image_path):
            os.remove(image_path)
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)
