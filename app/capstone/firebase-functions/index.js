const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure email transporter (using Gmail SMTP)
const transporter = nodemailer.createTransporter({
  service: 'gmail',
  auth: {
    user: functions.config().email.user, // Set this in Firebase config
    pass: functions.config().email.pass  // Set this in Firebase config
  }
});

// Function to send contact form emails
exports.sendContactFormEmail = functions.firestore
  .document('contact_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const contactData = snap.data();
    
    try {
      // Email to admin (you)
      const adminMailOptions = {
        from: functions.config().email.user,
        to: 'carolinegyireh@gmail.com', // Your email
        subject: `New Contact Request: ${contactData.subject}`,
        html: `
          <h2>New Contact Request Received</h2>
          <p><strong>From:</strong> ${contactData.name} (${contactData.email})</p>
          <p><strong>Category:</strong> ${contactData.category}</p>
          <p><strong>Subject:</strong> ${contactData.subject}</p>
          <p><strong>Message:</strong></p>
          <p>${contactData.message}</p>
          <p><strong>Timestamp:</strong> ${new Date(contactData.timestamp).toLocaleString()}</p>
        `
      };

      // Send email only to admin
      await transporter.sendMail(adminMailOptions);

      console.log('Contact form emails sent successfully');
      return null;
    } catch (error) {
      console.error('Error sending contact form emails:', error);
      throw error;
    }
  });

// Function to send feedback emails
exports.sendFeedbackEmail = functions.firestore
  .document('feedback/{feedbackId}')
  .onCreate(async (snap, context) => {
    const feedbackData = snap.data();
    
    try {
      // Email to admin (you)
      const adminMailOptions = {
        from: functions.config().email.user,
        to: 'carolinegyireh@gmail.com', // Your email
        subject: `New Feedback: ${feedbackData.subject || 'App Feedback'}`,
        html: `
          <h2>New Feedback Received</h2>
          <p><strong>From:</strong> ${feedbackData.name} (${feedbackData.email})</p>
          <p><strong>Subject:</strong> ${feedbackData.subject || 'App Feedback'}</p>
          <p><strong>Message:</strong></p>
          <p>${feedbackData.message}</p>
          <p><strong>Timestamp:</strong> ${new Date(feedbackData.timestamp).toLocaleString()}</p>
        `
      };

      // Send email only to admin
      await transporter.sendMail(adminMailOptions);

      console.log('Feedback emails sent successfully');
      return null;
    } catch (error) {
      console.error('Error sending feedback emails:', error);
      throw error;
    }
  }); 