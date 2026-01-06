import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/providers/attendance_provider.dart';
import 'package:provider/provider.dart';

class BiometricSimulatorButton extends StatelessWidget {
  const BiometricSimulatorButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    return FloatingActionButton.extended(
      onPressed: provider.isLoading ? null : () => provider.punchAction(),
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue,
      icon: provider.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.touch_app),
      label: Text(
        provider.isClockedIn ? "Simulate Scan Out" : "Simulate Scan In",
      ),
    );
  }
}
