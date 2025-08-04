const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure email transporter (you'll need to set up Gmail app password)
const transporter = nodemailer.createTransporter({
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com', // Replace with your email
    pass: 'your-app-password' // Replace with your Gmail app password
  }
});

// Cloud Function to send email when feedback is added to Firestore
exports.sendFeedbackEmail = functions.firestore
  .document('feedback/{feedbackId}')
  .onCreate(async (snap, context) => {
    const feedback = snap.data();
    
    const mailOptions = {
      from: 'your-email@gmail.com', // Replace with your email
      to: 'your-email@gmail.com', // Replace with your email
      subject: `SickleClinix Feedback from ${feedback.name}`,
      html: `
        <h2>New Feedback Received</h2>
        <p><strong>Name:</strong> ${feedback.name}</p>
        <p><strong>Email:</strong> ${feedback.email}</p>
        <p><strong>Message:</strong></p>
        <p>${feedback.message}</p>
        <p><strong>Timestamp:</strong> ${feedback.timestamp}</p>
        <hr>
        <p><em>This email was automatically sent from SickleClinix app.</em></p>
      `
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log('Feedback email sent successfully');
      return null;
    } catch (error) {
      console.error('Error sending feedback email:', error);
      return null;
    }
  });

// Cloud Function to send email when contact form is submitted
exports.sendContactEmail = functions.firestore
  .document('contact_requests/{contactId}')
  .onCreate(async (snap, context) => {
    const contact = snap.data();
    
    const mailOptions = {
      from: 'your-email@gmail.com', // Replace with your email
      to: 'your-email@gmail.com', // Replace with your email
      subject: `SickleClinix Contact: ${contact.subject}`,
      html: `
        <h2>New Contact Request</h2>
        <p><strong>Name:</strong> ${contact.name}</p>
        <p><strong>Email:</strong> ${contact.email}</p>
        <p><strong>Category:</strong> ${contact.category}</p>
        <p><strong>Subject:</strong> ${contact.subject}</p>
        <p><strong>Message:</strong></p>
        <p>${contact.message}</p>
        <p><strong>Timestamp:</strong> ${contact.timestamp}</p>
        <hr>
        <p><em>This email was automatically sent from SickleClinix app.</em></p>
      `
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log('Contact email sent successfully');
      return null;
    } catch (error) {
      console.error('Error sending contact email:', error);
      return null;
    }
  }); 