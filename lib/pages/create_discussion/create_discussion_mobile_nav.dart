import 'package:flutter/material.dart';

class CreateDiscussionMobileNav extends StatelessWidget {
  const CreateDiscussionMobileNav({
    super.key,
    required this.isSavingDraft,
    required this.isPublishing,
    required this.submitEnabled,
    required this.onOpenDrafts,
    required this.onSubmit,
    this.draftCount = 0,
    this.showDraftButton = true,
  });

  final bool isSavingDraft;
  final bool isPublishing;
  final bool submitEnabled;
  final VoidCallback onOpenDrafts;
  final VoidCallback onSubmit;
  final int draftCount;
  final bool showDraftButton;

  @override
  Widget build(BuildContext context) {
    final isBusy = isSavingDraft || isPublishing;
    final submitColor = submitEnabled
        ? const Color(0xffD7FF00)
        : Color.lerp(const Color(0xffD7FF00), Colors.white, 0.72)!;

    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xff181818),
        border: Border(
          top: BorderSide(color: Color(0xff2A2A2A), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showDraftButton)
            _ToolButton(
              icon: Icons.drafts_outlined,
              sublabel: draftCount > 0 ? '$draftCount' : null,
              onTap: onOpenDrafts,
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                showDraftButton ? 8 : 12,
                8,
                12,
                8,
              ),
              child: GestureDetector(
                onTap: submitEnabled && !isBusy ? onSubmit : null,
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: submitColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPublishing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      else if (isSavingDraft)
                        const Icon(
                          Icons.save_outlined,
                          color: Colors.black,
                          size: 18,
                        ),
                      if (isBusy) const SizedBox(width: 8),
                      Text(
                        isSavingDraft
                            ? '\u6b63\u5728\u4fdd\u5b58'
                            : '\u53d1\u5e03',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.onTap,
    this.sublabel,
  });

  final IconData icon;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xffA0A0A0), size: 24),
            if (sublabel != null) ...[
              const SizedBox(width: 6),
              Text(
                sublabel!,
                style: TextStyle(
                  color: const Color(0xffFBC02D).withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
