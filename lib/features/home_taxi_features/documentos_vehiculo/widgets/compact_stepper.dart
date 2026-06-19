import 'package:flutter/material.dart';

class CompactStepper extends StatelessWidget {
  const CompactStepper({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.onStepTapped,
    this.headerSpacing = 6, // ✅ controla distancia entre headers
    this.connectorHeight = 26, // ✅ altura de la línea entre pasos
    this.contentIndent = 60, // indent del contenido
  });

  final List<Step> steps;
  final int currentStep;
  final ValueChanged<int> onStepTapped;

  final double headerSpacing;
  final double connectorHeight;
  final double contentIndent;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: steps.length,
      itemBuilder: (context, i) {
        final step = steps[i];
        final isCurrent = i == currentStep;
        final isComplete = step.state == StepState.complete;
        final isActive = step.isActive;

        return Column(
          children: [
            _StepHeader(
              index: i,
              title: step.title,
              subtitle: step.subtitle,
              isCurrent: isCurrent,
              isComplete: isComplete,
              isActive: isActive,
              isLast: i == steps.length - 1,
              headerSpacing: headerSpacing,
              connectorHeight: connectorHeight,
              onTap: () => onStepTapped(i),
            ),

            // ✅ No reserva altura: SOLO muestra contenido en el step actual
            if (isCurrent)
              Padding(
                padding: EdgeInsets.only(
                  left: contentIndent,
                  right: 16,
                  top: 8,
                  bottom: 16,
                ),
                child: step.content,
              ),
          ],
        );
      },
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.isCurrent,
    required this.isComplete,
    required this.isActive,
    required this.isLast,
    required this.headerSpacing,
    required this.connectorHeight,
    required this.onTap,
  });

  final int index;
  final Widget title;
  final Widget? subtitle;

  final bool isCurrent;
  final bool isComplete;
  final bool isActive;
  final bool isLast;

  final double headerSpacing;
  final double connectorHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final lineColor = primary.withOpacity(0.7);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: headerSpacing,
          bottom: headerSpacing,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ícono + línea
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  _Circle(
                    index: index,
                    isComplete: isComplete,
                    isCurrent: isCurrent,
                    isActive: isActive,
                    primary: primary,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: connectorHeight,
                      color: lineColor,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      child: title,
                    ),
                    if (subtitle != null)
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.1,
                        ),
                        child: subtitle!,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.index,
    required this.isComplete,
    required this.isCurrent,
    required this.isActive,
    required this.primary,
  });

  final int index;
  final bool isComplete;
  final bool isCurrent;
  final bool isActive;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final bg =
        (isComplete || isCurrent || isActive) ? primary : Colors.grey.shade400;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isComplete
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }
}
