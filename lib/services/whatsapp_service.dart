import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class WhatsAppService {
  static const String adminPhone = "+918949821211"; // Default support number

  static Future<void> sendBookingReceipt({
    required String hikerName,
    required String tripName,
    required String bookingId,
    required double amount,
    required String date,
  }) async {
    final String message = 
      "🌟 *TREKWITHMUSSAFIRR BOOKING RECEIPT* 🌟\n\n"
      "Hello Admin,\n"
      "A new booking has been confirmed!\n\n"
      "📍 *Trip:* $tripName\n"
      "👤 *Hiker:* $hikerName\n"
      "📅 *Date:* $date\n"
      "💰 *Amount Paid:* ₹$amount\n"
      "🆔 *Booking ID:* $bookingId\n\n"
      "Please verify the payment in the dashboard.";

    final String url = "whatsapp://send?phone=$adminPhone&text=${Uri.encodeComponent(message)}";
    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web whatsapp if app is not installed
        final String webUrl = "https://wa.me/$adminPhone?text=${Uri.encodeComponent(message)}";
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("WhatsApp Launch Error: $e");
    }
  }

  static Future<void> sendUPIDetails({
    required String hikerName,
    required double amount,
    required String tripName,
  }) async {
    final String message = 
      "🙏 *UPI PAYMENT CONFIRMATION* 🙏\n\n"
      "Hi Admin,\n"
      "I ($hikerName) just initiated a UPI payment of *₹$amount* for the trip: *$tripName*.\n\n"
      "Please check and confirm.";

    final String webUrl = "https://wa.me/$adminPhone?text=${Uri.encodeComponent(message)}";
    await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
  }
  static Future<void> contactAdminForPayment({
    required String hikerName,
    required String tripName,
    required String bookingId,
    required String method,
  }) async {
    final String message = 
      "👋 *PAYMENT VERIFICATION REQUEST* 👋\n\n"
      "Hello Admin,\n"
      "I've just booked a trip and chose *$method* as my payment method.\n\n"
      "👤 *Name:* $hikerName\n"
      "🏔️ *Trip:* $tripName\n"
      "🆔 *Booking ID:* $bookingId\n\n"
      "Please let me know how to proceed or confirm if you've received the funds.";

    final String webUrl = "https://wa.me/$adminPhone?text=${Uri.encodeComponent(message)}";
    await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
  }
}
