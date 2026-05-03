import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/whatsapp_service.dart';

class MockPaymentFlow extends StatefulWidget {
  final double total;
  final VoidCallback onComplete;

  const MockPaymentFlow({super.key, required this.total, required this.onComplete});

  @override
  State<MockPaymentFlow> createState() => _MockPaymentFlowState();
}

class _MockPaymentFlowState extends State<MockPaymentFlow> {
  bool _isProcessing = false;
  String _statusMessage = "Select Payment Method";

  void _processPayment() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Initiating Secure Transaction...";
    });
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _statusMessage = "Verifying with Bank...");
    }
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 24),
            Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SECURE CHECKOUT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text('SSL SECURE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Total Payable: ₹${widget.total.toInt()}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primary)),
          const SizedBox(height: 30),
          _paymentOption(
            icon: Icons.account_balance_wallet_outlined,
            title: 'UPI (GPay, PhonePe, Paytm)',
            sub: 'Pay directly via any UPI app',
            onTap: () async {
              final upiUri = Uri.parse("upi://pay?pa=tripindia@okaxis&pn=Trip%20India&am=${widget.total}&tn=Trip%20Booking&cu=INR");
              try {
                if (await canLaunchUrl(upiUri)) {
                  await launchUrl(upiUri, mode: LaunchMode.externalApplication);
                  _processPayment();
                } else {
                  _showQRCodeFallback(upiUri.toString());
                }
              } catch (e) {
                _showQRCodeFallback(upiUri.toString());
              }
            }
          ),
          const SizedBox(height: 16),
          _paymentOption(
            icon: Icons.credit_card_outlined,
            title: 'Cards / Net Banking',
            sub: 'Visa, Master, Rupay supported',
            onTap: _processPayment,
          ),
          const SizedBox(height: 16),
          _paymentOption(
            icon: Icons.chat_outlined,
            title: 'WhatsApp Confirmation',
            sub: 'Pay manually & send screenshot',
            onTap: () {
              WhatsAppService.sendUPIDetails(
                hikerName: "Hiker", 
                amount: widget.total, 
                tripName: "Current Trip"
              );
              _processPayment();
            }
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _paymentOption({required IconData icon, required String title, required String sub, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showQRCodeFallback(String upiUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan to Pay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Image.network(
                "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(upiUrl)}",
                width: 200,
                height: 200,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Scan this QR with any UPI app (GPay, PhonePe, Paytm)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(c);
                  _processPayment();
                },
                child: const Text('I HAVE PAID', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
