import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet-Friendly Terms'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          '''
SmartFeed Pet-Friendly Terms & Conditions

Welcome to SmartFeed! 🐾

SmartFeed is designed to help pet owners manage feeding schedules, monitor feeding activity, and make everyday pet care more convenient.

1. Using SmartFeed

SmartFeed is intended to assist pet owners with managing and monitoring their pets' feeding routines.

You are responsible for making sure that the feeding schedules and portion sizes you configure are appropriate for your pet.

2. Your Pet's Well-Being

Your pet's health and safety always come first.

SmartFeed's feeding recommendations are intended to provide helpful suggestions and are not a substitute for professional veterinary advice.

If you have concerns about your pet's diet, weight, eating behavior, or health, consult a qualified veterinarian.

3. Feeding Schedules

You are responsible for checking that:

• Feeding times are correct.
• Portions are appropriate for your pet.
• The feeder contains enough food.
• The feeder is properly powered and functioning.
• Your pet has access to fresh drinking water.

4. AI Recommendations

SmartFeed may analyze feeding history to provide suggestions about feeding schedules or portions.

AI-generated recommendations are provided for general guidance only and may not be suitable for every pet.

5. Pet Detection

SmartFeed may use camera-based pet detection to identify when a pet is near the feeder.

Detection results may not always be accurate because of lighting, camera positioning, movement, network conditions, or other environmental factors.

6. Notifications

SmartFeed may send notifications about pet detection, low food levels, and other system events.

Notifications may occasionally be delayed or unavailable because of internet connectivity, device settings, or technical issues.

7. Hardware and Connectivity

SmartFeed may depend on hardware components, Wi-Fi connectivity, power, sensors, cameras, and other connected devices.

Temporary failures may occur because of power interruptions, network problems, sensor errors, hardware damage, software errors, or incorrect configuration.

8. Responsible Pet Ownership

SmartFeed is a tool to assist pet owners and is not a replacement for responsible pet care.

Pet owners remain responsible for providing appropriate food and water, monitoring their pet's health, maintaining the feeder, and responding to system warnings.

9. Changes to These Terms

These terms may be updated when SmartFeed's features or policies change.

10. Acceptance

By using SmartFeed, you acknowledge that you have read and understood these Terms & Conditions and agree to use SmartFeed responsibly.

🐾 Feed smart. Care more. Love always.
''',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}