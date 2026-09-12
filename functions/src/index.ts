import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

export { validateMove } from './validateMove';
export { claimTimeout, scheduledTimeoutSweeper } from './enforceTimeout';
