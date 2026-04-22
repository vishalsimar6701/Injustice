import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DisclaimerScreen extends StatefulWidget {
  final VoidCallback onAccepted;

  const DisclaimerScreen({super.key, required this.onAccepted});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.midnightBlue, Colors.black],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.gavel_rounded, color: AppTheme.goldAccent, size: 64),
                const SizedBox(height: 24),
                Text(
                  'INJUSTICE: LEGAL NOTICE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppTheme.goldAccent,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(13), 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.goldAccent.withAlpha(77)), 
                      ),
                      child: const Text(
                        '''
Disclaimer and Terms of Use (India - IT Rules 2021 Compliant):

1. PROTOCOL BROWSER STATUS: "Injustice" is a decentralized client/browser for the Nostr protocol. We do not host, own, or control the content you see. All data is hosted on independent "Relays" globally.

2. INTERMEDIARY LIMITATIONS: As per Section 79 of the IT Act, 2000, this app is a tool for accessing third-party content. We do not initiate transmissions, select receivers, or modify the information contained in any transmission.

3. PROHIBITED CONTENT: Users are prohibited from using this protocol to share content that is illegal, defamatory, or threatens the sovereignty of India. Since we do not host the content, users must also comply with the Terms of Service of the specific Relays they connect to.

4. GRIEVANCE REDRESSAL: 
   - Local: Users can "Report" or "Block" to hide content instantly from their own device.
   - Global: For legal takedown requests under IT Rules 2021, please contact our Grievance Officer:
     Name: [Insert Name]
     Email: grievance@injustice-app.io
     We will acknowledge complaints within 24 hours and act upon valid legal orders by filtering access within this client.

5. NO LIABILITY: You use this decentralized network at your own risk. The developers are not responsible for content hosted on external relays.
                       ''',                        style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Checkbox(
                      value: _isAccepted,
                      onChanged: (val) => setState(() => _isAccepted = val ?? false),
                      fillColor: WidgetStateProperty.all(AppTheme.goldAccent), // Fixed WidgetStateProperty
                    ),
                    const Expanded(
                      child: Text(
                        'I accept sole legal responsibility for my posts.',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isAccepted ? widget.onAccepted : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAccepted ? AppTheme.goldAccent : Colors.grey,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('ENTER PLATFORM'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
