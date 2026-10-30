const { createApp } = require('./app');

const port = process.env.PORT || 3000;

createApp().listen(port, '0.0.0.0', () => {
  console.log(`API PetCare : http://localhost:${port}/api/health`);
});
