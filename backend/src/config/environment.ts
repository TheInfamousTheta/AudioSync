import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  PORT: process.env.PORT || 4000,
  // Fallback to a mock/public engine until your laptop/Azure setup is active
  SAAVN_API_URL: process.env.SAAVN_API_URL || 'https://saavn.me',
};
