import 'package:flutter/material.dart';

import 'package:hrflow_mobile/core/design_tokens.dart';
import 'package:hrflow_mobile/core/theme.dart';

class WorkspaceDemoBanner extends StatelessWidget {
  const WorkspaceDemoBanner({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Container(
      width: double.infinity,
      color: context.semantic.successBackground,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.x1,
        horizontal: AppSpacing.x4,
      ),
      child: Text(
        'DEMO WORKSPACE  ·  Fictional data',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: context.semantic.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
