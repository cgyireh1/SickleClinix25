
# SickleClinix

**An ML-powered mobile diagnostic app to aid with the early detection of Sickle Cell Disease (SCD) with explainable analysis**


## Overview

**SickleClinix** is a mobile-first healthcare application designed to assist in the early detection and management of Sickle Cell Disease, particularly in under-resourced healthcare settings. The system leverages computer vision, machine learning, and mobile technology to analyze blood smear images, predict SCD presence, with a Grad-CAM for explainability((Helps healthcare workers to know which part of the image influenced the model's decision).


## Objectives

- Detect Sickle Cell Disease using a trained CNN(MobileNetV2) on blood smear images.
- Provide explainable predictions using Grad-CAM.
- Offer offline-first support with cloud sync.
- Deliver historical tracking.
- Improve healthcare accessibility for vulnerable populations.


## Core Features

- **Image Classification (Normal vs Sickle)** using MobileNetV2.
- **Grad-CAM Explainability** for heatmap overlays.
- **Flutter Mobile App** with modern UI.
- **Offline Support** with local storage.
- **History, Notifications, Reports*


## Tech Stack

| Layer          | Technology                                   |
|----------------|----------------------------------------------|
| Mobile App     | Flutter, Dart                                |
| ML Models      | TensorFlow, Keras, TFLite                    |
| Backend        | Python, Flask                                |
| Explainability | Grad-CAM, OpenCV                             |
| Data           | albumentations,tensorflow(ImageDataGenerator)|
| Cloud          | Firebase                                     |


## Folder Structure
```

SickleClinix25/
├── app/                  # Flutter app source code
├── Grad-CAM backend/     # Flask API for grad-cam
├── notebooks/            # Jupyter Notebooks for training and evaluation
├── assets/               # Images
├── README.md
├── requirements.txt      # Python dependencies for backend and training
├── .gitignore
└── LICENSE
```

## Getting Started

### Clone the repo
```bash
git clone https://github.com/cgyireh1/SickleClinix25.git
cd SickleClinix25
````

### Run the Mobile App

```bash
cd app
flutter pub get
flutter run
```

###  Train or Test Model

```bash
cd notebooks
```
Open and run the cells in SickleClinix_model_training_evaluation.ipynb

## Model Performance

| Metric    | Value |
| --------- | ----- |
| Accuracy  | 0.95  |
| Precision | 0.95  |
| Recall    | 0.95  |
| ROC-AUC   | 0.99  |

Here's a clear and professional way to describe each of the visuals in your README file. These explanations are tailored for a capstone project or machine learning app like **SickleClinix**, and they balance technical depth with clarity for both academic and non-technical audiences.

---

### Classification Report

<img width="435" height="182" alt="class-report" src="https://github.com/user-attachments/assets/32f274a6-7b66-456a-acfa-93dc3d1c9bbc" />

This classification report provides a detailed breakdown of the model’s performance on the test dataset. Key metrics include:

* **Precision**: Measures how many of the predicted positives are actually positive.
* **Recall**: Indicates how many actual positives were correctly identified.
* **F1-Score**: Harmonic mean of precision and recall, representing the balance between the two.
* **Support**: The number of true instances for each class.

High precision and recall values for both `Normal` and `Sickle` classes demonstrate the model's strong ability to distinguish between healthy and sickled cells.


### Confusion Matrix

<img width="400" height="400" alt="cm-1" src="https://github.com/user-attachments/assets/622dcc88-37c3-405a-ab36-ba197bb5564f" />

The confusion matrix visualizes the true vs. predicted classifications. It helps identify where the model performs well and where it misclassifies:

* **True Positives/Negatives (Green--diagonal)**: Correctly predicted cell images.
* **False Positives/Negatives (Off-diagonal)**: Misclassifications.

A low number of off-diagonal errors indicates reliable model predictions, which is critical in clinical settings where accuracy is vital.


### Grad-CAM Visualization

<img width="989" height="364" alt="grad-cam" src="https://github.com/user-attachments/assets/7f8a36c0-ea40-49b0-917e-dcc9857735e7" />

Grad-CAM (Gradient-weighted Class Activation Mapping) provides visual explainability by highlighting the areas in the blood smear image that influenced the model’s prediction.

* Redder regions represent higher importance.
* This helps clinicians or researchers verify that the model is focusing on relevant regions, such as malformed or sickled red blood cells.

Incorporating Grad-CAM improves trust and transparency in the model, which is especially important in medical diagnostics.


## Ethical Considerations

This project follows the **IEEE Code of Ethics** guidelines. 

All predictions include confidence scores and disclaimers, ensuring informed use in healthcare settings.


##  Author
**Caroline Gyireh**

GitHub: [@cgyireh1](https://github.com/cgyireh1)

Email Me @: [c.gyireh@alustudent.com](c.gyireh@alustudent.com)


## License

This project is licensed under the [MIT License](LICENSE).


## Acknowledgements

* Supervisors: Samiratu Ntoshi
* Institution: African Leadership University
* Data: Kaggle (Florence Tushabe)
* OpenAI, TensorFlow, Flutter, Firebase
