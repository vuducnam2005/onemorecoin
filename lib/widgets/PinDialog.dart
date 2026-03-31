import 'package:flutter/material.dart';

class PinDialog extends StatefulWidget {
  final String title;
  final String? errorText;

  const PinDialog({
    super.key,
    required this.title,
    this.errorText,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String pin = "";
  final int pinLength = 6;

  void _onKeyPress(String value) {
    if (pin.length < pinLength) {
      setState(() {
        pin += value;
      });
      if (pin.length == pinLength) {
        // Automatically submit when 6 digits are reached
        Navigator.pop(context, pin);
      }
    }
  }

  void _onDelete() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  Widget _buildKeyPadButton(String label, {VoidCallback? onPressed, Widget? icon}) {
    return Expanded(
      child: InkWell(
        onTap: onPressed ?? () => _onKeyPress(label),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: icon ?? Text(
            label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Pin dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pinLength, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < pin.length 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade400,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            if (widget.errorText != null)
              Text(
                widget.errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            const Spacer(),
            // Numpad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildKeyPadButton('1'),
                      _buildKeyPadButton('2'),
                      _buildKeyPadButton('3'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildKeyPadButton('4'),
                      _buildKeyPadButton('5'),
                      _buildKeyPadButton('6'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildKeyPadButton('7'),
                      _buildKeyPadButton('8'),
                      _buildKeyPadButton('9'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: const SizedBox()), // Empty space
                      _buildKeyPadButton('0'),
                      _buildKeyPadButton('', 
                        onPressed: _onDelete, 
                        icon: const Icon(Icons.backspace_outlined, size: 28)
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
