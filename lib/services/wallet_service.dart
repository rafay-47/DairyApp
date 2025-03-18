import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Get user wallet document reference
  DocumentReference get _walletRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('wallet')
      .doc('balance');

  // Get user wallet transactions collection reference
  CollectionReference get _transactionsRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('wallet_transactions');

  // Get the current wallet balance
  Future<double> getWalletBalance() async {
    try {
      if (_userId == null) {
        return 0.0; // User not logged in
      }

      final DocumentSnapshot walletDoc = await _walletRef.get();

      if (!walletDoc.exists) {
        // Create wallet for new user with 0 balance
        await _walletRef.set({'balance': 0.0});
        return 0.0;
      }

      final data = walletDoc.data() as Map<String, dynamic>?;
      final balance = data?['balance'] ?? 0.0;
      return balance is num ? balance.toDouble() : 0.0;
    } catch (e) {
      print('Error fetching wallet balance: $e');
      return 0.0;
    }
  }

  // Add money to wallet
  Future<bool> addMoney(
    double amount,
    String source,
    String referenceId,
  ) async {
    try {
      if (_userId == null || amount <= 0) {
        return false;
      }

      // Update wallet balance using transaction to ensure atomicity
      return await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(_walletRef);

        double currentBalance = 0.0;
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          currentBalance = data?['balance'] ?? 0.0;
          if (currentBalance is! num) {
            currentBalance = 0.0;
          }
        }

        final newBalance = currentBalance + amount;

        // Update wallet balance
        transaction.set(_walletRef, {
          'balance': newBalance,
        }, SetOptions(merge: true));

        // Record transaction
        final transactionData = {
          'amount': amount,
          'type': 'CREDIT',
          'description': 'Added via $source',
          'referenceId': referenceId,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': _userId,
        };

        transaction.set(_transactionsRef.doc(), transactionData);

        return true;
      });
    } catch (e) {
      print('Error adding money to wallet: $e');
      return false;
    }
  }

  // Deduct money from wallet
  Future<bool> deductMoney(
    double amount,
    String description,
    String orderId,
  ) async {
    try {
      if (_userId == null || amount <= 0) {
        return false;
      }

      // Update wallet balance using transaction to ensure atomicity
      return await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(_walletRef);

        if (!snapshot.exists) {
          return false; // Wallet doesn't exist
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        double currentBalance = data?['balance'] ?? 0.0;
        if (currentBalance is! num) {
          currentBalance = 0.0;
        }

        // Check if enough balance
        if (currentBalance < amount) {
          return false; // Insufficient balance
        }

        final newBalance = currentBalance - amount;

        // Update wallet balance
        transaction.set(_walletRef, {
          'balance': newBalance,
        }, SetOptions(merge: true));

        // Record transaction
        final transactionData = {
          'amount': amount,
          'type': 'DEBIT',
          'description': description,
          'orderId': orderId,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': _userId,
        };

        transaction.set(_transactionsRef.doc(), transactionData);

        return true;
      });
    } catch (e) {
      print('Error deducting money from wallet: $e');
      return false;
    }
  }

  // Get wallet transaction history
  Future<List<DocumentSnapshot>> getTransactionHistory() async {
    try {
      if (_userId == null) {
        return [];
      }

      // Check if collection exists
      final collectionRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('wallet_transactions');
      final collectionSnapshot = await collectionRef.limit(1).get();

      if (collectionSnapshot.docs.isEmpty) {
        return []; // Collection is empty or doesn't exist
      }

      // Get transactions sorted by timestamp (newest first)
      final querySnapshot =
          await _transactionsRef.orderBy('timestamp', descending: true).get();

      return querySnapshot.docs;
    } catch (e) {
      print('Error fetching transaction history: $e');
      return [];
    }
  }

  // Check if wallet has sufficient balance
  Future<bool> hasSufficientBalance(double amount) async {
    if (amount <= 0) return true;

    final balance = await getWalletBalance();
    return balance >= amount;
  }

  // Initialize wallet for a new user
  Future<void> initializeWallet() async {
    if (_userId == null) return;

    final walletDoc = await _walletRef.get();
    if (!walletDoc.exists) {
      await _walletRef.set({'balance': 0.0});
    }
  }

  // Transfer money from one user to another (for future peer transfers)
  Future<bool> transferMoney(
    String recipientUserId,
    double amount,
    String description,
  ) async {
    try {
      if (_userId == null || recipientUserId.isEmpty || amount <= 0) {
        return false;
      }

      final recipientWalletRef = _firestore
          .collection('users')
          .doc(recipientUserId)
          .collection('wallet')
          .doc('balance');

      // Use a batch to ensure all operations succeed or fail together
      return await _firestore.runTransaction<bool>((transaction) async {
        // Check sender's balance
        final senderSnapshot = await transaction.get(_walletRef);
        if (!senderSnapshot.exists) {
          return false;
        }

        final senderData = senderSnapshot.data() as Map<String, dynamic>?;
        double senderBalance = senderData?['balance'] ?? 0.0;
        if (senderBalance < amount) {
          return false; // Insufficient balance
        }

        // Check if recipient wallet exists
        final recipientSnapshot = await transaction.get(recipientWalletRef);
        double recipientBalance = 0.0;

        if (recipientSnapshot.exists) {
          final recipientData =
              recipientSnapshot.data() as Map<String, dynamic>?;
          recipientBalance = recipientData?['balance'] ?? 0.0;
        }

        // Update sender's balance
        transaction.update(_walletRef, {'balance': senderBalance - amount});

        // Update recipient's balance
        transaction.set(recipientWalletRef, {
          'balance': recipientBalance + amount,
        }, SetOptions(merge: true));

        // Create transaction record for sender
        final senderTransactionData = {
          'amount': amount,
          'type': 'DEBIT',
          'description': 'Transfer to user: $description',
          'recipientId': recipientUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': _userId,
        };

        transaction.set(_transactionsRef.doc(), senderTransactionData);

        // Create transaction record for recipient
        final recipientTransactionRef =
            _firestore
                .collection('users')
                .doc(recipientUserId)
                .collection('wallet_transactions')
                .doc();

        final recipientTransactionData = {
          'amount': amount,
          'type': 'CREDIT',
          'description': 'Received from: $description',
          'senderId': _userId,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': recipientUserId,
        };

        transaction.set(recipientTransactionRef, recipientTransactionData);

        return true;
      });
    } catch (e) {
      print('Error transferring money: $e');
      return false;
    }
  }
}
