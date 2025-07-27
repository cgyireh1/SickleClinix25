
# SickleClinix

**An ML-powered mobile diagnostic app to aid with the early detection of Sickle Cell Disease (SCD) with explainable analysis**


## Overview

**SickleClinix** is a mobile-first healthcare application designed to assist in the early detection and management of Sickle Cell Disease, particularly in under-resourced healthcare settings. The system leverages computer vision, machine learning, and mobile technology to analyze blood smear images, predict SCD presence, with a Grad-CAM for explainability((Helps healthcare workers to know which part of the image influenced the model's decision).


## Objectives

- Detect Sickle Cell Disease using a trained CNN on blood smear images.
- Provide explainable predictions using Grad-CAM.
- Enable role-based access (doctor, nurse, lab technician, admin).
- Offer offline-first support with optional cloud sync.
- Deliver triage, historical tracking, reports, and educational materials.
- Improve healthcare accessibility for vulnerable populations.


## Core Features

- **Image Classification (Normal vs Sickle)** using MobileNetV2.
- **Grad-CAM Explainability** for heatmap overlays.
- **Flutter Mobile App** with modern UI.
- **Offline Support** with local storage.
- **Role-based Dashboards** and secure login system.
- **Triage & Severity Assessment** from image results.
- **Reports, History, Notifications, Educational Content**


## Tech Stack

| Layer          | Technology                                   |
|----------------|----------------------------------------------|
| Mobile App     | Flutter, Dart                                |
| ML Models      | TensorFlow, Keras, TFLite                    |
| Backend        | Python, Flask                                |
| Explainability | Grad-CAM, OpenCV                             |
| Data           | Augmented Blood Smear Dataset                |
| Cloud          | Firebase                                     |


## Folder Structure

SickleClinix25/

│

├── app/                                           # Flutter app source code

├── model/                                         # Trained models

├── backend/                                       # Flask API

├── notebooks/                                     # Training & evaluation Notebooks

├── docs/                                          # Project proposal, report, ethics, user manual

├── assets/                                        # Images, logos, heatmaps

├── README.md

├── requirements.txt                              # Python packages

├── pubspec.yaml                                  # Flutter dependencies

├── .gitignore

└── LICENSE

````

## Getting Started

### 🔹 Clone the repo
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
# Open and run MobileNetV2/Grad-CAM.ipynb
```

## 📊 Model Performance

| Metric    | Value |
| --------- | ----- |
| Accuracy  | 0.95 |
| Precision | 0.94  |
| Recall    | 0.96  |
| ROC-AUC   | 0.99 |


<img width="435" height="182" alt="class-report" src="https://github.com/user-attachments/assets/32f274a6-7b66-456a-acfa-93dc3d1c9bbc" />


<img width="400" height="400" alt="cm-1" src="https://github.com/user-attachments/assets/622dcc88-37c3-405a-ab36-ba197bb5564f" />


<img width="989" height="364" alt="grad-cam" src="https://github.com/user-attachments/assets/7f8a36c0-ea40-49b0-917e-dcc9857735e7" />

## Ethical Considerations

This project follows the **IEEE Code of Ethics**, **Belmont Report**, and **local CHRPE/IRB** guidelines. All predictions include confidence scores and disclaimers, ensuring informed use in healthcare settings.


##  Author

**Caroline Gyireh**

GitHub: [@cgyireh1](https://github.com/cgyireh1)

Email Me @: [c.gyireh@alustudent.com](c.gyireh@alustudent.com)


## License

This project is licensed under the [MIT License](LICENSE).


## Acknowledgements

* Supervisors: Samiratu Ntoshi
* Institution: African Leadership University
* Data Source: Kaggle
* OpenAI, TensorFlow, Flutter, Firebase
