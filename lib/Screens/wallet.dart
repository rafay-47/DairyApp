import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Constants.dart';
import '../Services/wallet_service.dart';
import 'payment.dart';
import 'package:intl/intl.dart';
import 'package:toast/toast.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  bool isLoading = false;
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    setState(() {
      isLoading = true;
    });

    try {
      final balance = await _walletService.getWalletBalance();
      setState(() {
        _walletBalance = balance;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading wallet: $e')));
    }
  }

  void _showAddMoneyDialog() {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Money to Wallet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter amount to add to your wallet'),
                SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    labelText: 'Amount',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _processWalletTopUp(amount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                ),
                child: Text('PROCEED'),
              ),
            ],
          ),
    );
  }

  Future<void> _processWalletTopUp(double amount) async {
    setState(() {
      isLoading = true;
    });

    final paymentService = StripePaymentService();

    await paymentService.makePayment(
      amount: amount,
      context: context,
      onSuccess: () async {
        // Generate a reference ID for this transaction
        final String referenceId =
            'TOPUP${DateTime.now().millisecondsSinceEpoch}';

        // Add money to wallet
        await _walletService.addMoney(amount, 'Stripe', referenceId);

        // Reload wallet balance
        await _loadWalletBalance();

        setState(() {
          isLoading = false;
        });

        // Show success toast
        Toast.show(
          'Successfully added ₹${amount.toStringAsFixed(2)} to your wallet',
          duration: Toast.lengthLong,
          gravity: Toast.bottom,
        );
      },
      onError: (String errorMessage) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        title: Text('My Wallet'),
        backgroundColor: Constants.primaryColor,
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadWalletBalance,
                child: Column(
                  children: [
                    // Wallet balance card
                    Card(
                      margin: EdgeInsets.all(16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Constants.primaryColor,
                              Constants.accentColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet Balance',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '₹ ${_walletBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _showAddMoneyDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Constants.primaryColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('ADD MONEY'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Transactions header
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Recent Transactions',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Transactions list
                    Expanded(
                      child: FutureBuilder<List<DocumentSnapshot>>(
                        future: _walletService.getTransactionHistory(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          final transactions = snapshot.data ?? [];

                          if (snapshot.hasError || transactions.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    snapshot.hasError
                                        ? 'Unable to load transaction history'
                                        : 'No transactions yet',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (snapshot.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            // Force refresh
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Constants.primaryColor,
                                        ),
                                        child: Text('Retry'),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final transaction =
                                  transactions[index].data()
                                      as Map<String, dynamic>;
                              final amount = transaction['amount'] ?? 0.0;
                              final type = transaction['type'] ?? '';
                              final description =
                                  transaction['description'] ?? '';
                              final timestamp =
                                  transaction['timestamp'] as Timestamp?;
                              final formattedDate =
                                  timestamp != null
                                      ? DateFormat(
                                        'MMM dd, yyyy • hh:mm a',
                                      ).format(timestamp.toDate())
                                      : 'Unknown date';

                              return Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        type == 'CREDIT'
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                    child: Icon(
                                      type == 'CREDIT'
                                          ? Icons.add
                                          : Icons.remove,
                                      color:
                                          type == 'CREDIT'
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  ),
                                  title: Text(description),
                                  subtitle: Text(formattedDate),
                                  trailing: Text(
                                    '${type == 'CREDIT' ? '+' : '-'} ₹${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          type == 'CREDIT'
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
