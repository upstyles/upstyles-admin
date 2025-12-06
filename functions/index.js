const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// Helper function to set moderator claims
exports.setModeratorClaims = onRequest(async (req, res) => {
  // SECURITY: This should be protected! Only allow from specific IPs or require admin token
  // For initial setup, we'll add basic security
  
  const {uid, email, secret} = req.body;
  
  // Simple secret check (replace with your own secret)
  if (secret !== "SETUP_SECRET_2024") {
    return res.status(403).json({error: "Unauthorized"});
  }

  if (!uid && !email) {
    return res.status(400).json({error: "uid or email required"});
  }

  try {
    let user;
    if (uid) {
      user = await admin.auth().getUser(uid);
    } else {
      user = await admin.auth().getUserByEmail(email);
    }

    await admin.auth().setCustomUserClaims(user.uid, {
      moderator: true,
      role: "admin",
    });

    res.json({
      success: true,
      message: `Moderator claims set for ${user.email}`,
      uid: user.uid,
    });
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

// List all moderators
exports.listModerators = onRequest(async (req, res) => {
  const {secret} = req.query;
  
  if (secret !== "SETUP_SECRET_2024") {
    return res.status(403).json({error: "Unauthorized"});
  }

  try {
    const listUsersResult = await admin.auth().listUsers();
    const moderators = listUsersResult.users
        .filter((user) => user.customClaims?.moderator === true)
        .map((user) => ({
          uid: user.uid,
          email: user.email,
          role: user.customClaims?.role,
        }));

    res.json({moderators});
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});
