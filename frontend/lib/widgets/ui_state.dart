import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Core UI state types for screens across the application.
enum UiStateType {
  idle,
  loading,
  processing,
  error,
  empty,
  success,
  disabled,
  offline,
}

/// Unified UI State View that renders the appropriate state component,
/// or renders [child] when in the [UiStateType.idle] state.
class UiStateView extends StatelessWidget {
  final UiStateType state;
  final Widget? child;
  final String? title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onCancel;
  final double? progress;

  const UiStateView({
    super.key,
    required this.state,
    this.child,
    this.title,
    this.message,
    this.icon,
    this.onRetry,
    this.retryLabel,
    this.onAction,
    this.actionLabel,
    this.onCancel,
    this.progress,
  });

  /// Factory for Loading state
  const factory UiStateView.loading({
    Key? key,
    String? message,
  }) = _UiStateViewLoading;

  /// Factory for Processing state
  const factory UiStateView.processing({
    Key? key,
    String? title,
    String? message,
    double? progress,
    VoidCallback? onCancel,
  }) = _UiStateViewProcessing;

  /// Factory for Error state
  const factory UiStateView.error({
    Key? key,
    String? title,
    required String message,
    VoidCallback? onRetry,
    String? retryLabel,
  }) = _UiStateViewError;

  /// Factory for Empty state
  const factory UiStateView.empty({
    Key? key,
    String? title,
    required String message,
    IconData? icon,
    VoidCallback? onAction,
    String? actionLabel,
  }) = _UiStateViewEmpty;

  /// Factory for Success state
  const factory UiStateView.success({
    Key? key,
    String? title,
    String? message,
    IconData? icon,
    VoidCallback? onAction,
    String? actionLabel,
  }) = _UiStateViewSuccess;

  /// Factory for Disabled state
  const factory UiStateView.disabled({
    Key? key,
    String? title,
    required String message,
    IconData? icon,
    VoidCallback? onAction,
    String? actionLabel,
  }) = _UiStateViewDisabled;

  /// Factory for Offline state
  const factory UiStateView.offline({
    Key? key,
    String? title,
    String? message,
    VoidCallback? onRetry,
    String? retryLabel,
  }) = _UiStateViewOffline;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case UiStateType.loading:
        return UiLoadingView(message: message);
      case UiStateType.processing:
        return UiProcessingView(
          title: title,
          message: message,
          progress: progress,
          onCancel: onCancel,
        );
      case UiStateType.error:
        return UiErrorView(
          title: title,
          message: message ?? 'An error occurred.',
          onRetry: onRetry,
          retryLabel: retryLabel,
        );
      case UiStateType.empty:
        return UiEmptyView(
          title: title,
          message: message ?? 'No items available.',
          icon: icon,
          onAction: onAction,
          actionLabel: actionLabel,
        );
      case UiStateType.success:
        return UiSuccessView(
          title: title ?? 'Completed',
          message: message,
          icon: icon,
          onAction: onAction,
          actionLabel: actionLabel,
        );
      case UiStateType.disabled:
        return UiDisabledView(
          title: title,
          message: message ?? 'Action unavailable.',
          icon: icon,
          onAction: onAction,
          actionLabel: actionLabel,
        );
      case UiStateType.offline:
        return UiOfflineView(
          title: title,
          message: message,
          onRetry: onRetry,
          retryLabel: retryLabel,
        );
      case UiStateType.idle:
        return child ?? const SizedBox.shrink();
    }
  }
}

class _UiStateViewLoading extends UiStateView {
  const _UiStateViewLoading({super.key, super.message})
      : super(state: UiStateType.loading);
}

class _UiStateViewProcessing extends UiStateView {
  const _UiStateViewProcessing({
    super.key,
    super.title,
    super.message,
    super.progress,
    super.onCancel,
  }) : super(state: UiStateType.processing);
}

class _UiStateViewError extends UiStateView {
  const _UiStateViewError({
    super.key,
    super.title,
    required super.message,
    super.onRetry,
    super.retryLabel,
  }) : super(state: UiStateType.error);
}

class _UiStateViewEmpty extends UiStateView {
  const _UiStateViewEmpty({
    super.key,
    super.title,
    required super.message,
    super.icon,
    super.onAction,
    super.actionLabel,
  }) : super(state: UiStateType.empty);
}

class _UiStateViewSuccess extends UiStateView {
  const _UiStateViewSuccess({
    super.key,
    super.title,
    super.message,
    super.icon,
    super.onAction,
    super.actionLabel,
  }) : super(state: UiStateType.success);
}

class _UiStateViewDisabled extends UiStateView {
  const _UiStateViewDisabled({
    super.key,
    super.title,
    required super.message,
    super.icon,
    super.onAction,
    super.actionLabel,
  }) : super(state: UiStateType.disabled);
}

class _UiStateViewOffline extends UiStateView {
  const _UiStateViewOffline({
    super.key,
    super.title,
    super.message,
    super.onRetry,
    super.retryLabel,
  }) : super(state: UiStateType.offline);
}

// ---------------------------------------------------------------------------
// 1. Loading Component
// ---------------------------------------------------------------------------
class UiLoadingView extends StatelessWidget {
  final String? message;

  const UiLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Processing Component
// Used for uploading, payments, OTP verification, queueing print, invoice gen.
// ---------------------------------------------------------------------------
class UiProcessingView extends StatelessWidget {
  final String? title;
  final String? message;
  final double? progress;
  final VoidCallback? onCancel;

  const UiProcessingView({
    super.key,
    this.title,
    this.message,
    this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'Processing',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress! * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Overlay container that shows a modal processing card over [child]
/// while [isProcessing] is true, blocking touch interactions.
class UiProcessingOverlay extends StatelessWidget {
  final bool isProcessing;
  final String? title;
  final String? message;
  final double? progress;
  final VoidCallback? onCancel;
  final Widget child;

  const UiProcessingOverlay({
    super.key,
    required this.isProcessing,
    required this.child,
    this.title,
    this.message,
    this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isProcessing) ...[
          const ModalBarrier(
            dismissible: false,
            color: Color(0x55000000),
          ),
          UiProcessingView(
            title: title,
            message: message,
            progress: progress,
            onCancel: onCancel,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Error Component
// ---------------------------------------------------------------------------
class UiErrorView extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const UiErrorView({
    super.key,
    this.title,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.dangerSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dangerBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.dangerBorder),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            if (title != null && title!.isNotEmpty) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.danger,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.danger,
                height: 1.35,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(retryLabel ?? 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Empty Component
// ---------------------------------------------------------------------------
class UiEmptyView extends StatelessWidget {
  final String? title;
  final String message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const UiEmptyView({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                color: AppTheme.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title ?? 'No items found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: Size.zero,
                ),
                child: Text(actionLabel ?? 'Refresh'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Success Component
// ---------------------------------------------------------------------------
class UiSuccessView extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const UiSuccessView({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.successSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.successBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.check_circle_rounded,
                color: AppTheme.success,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(actionLabel ?? 'Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Disabled Component
// ---------------------------------------------------------------------------
class UiDisabledView extends StatelessWidget {
  final String? title;
  final String message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const UiDisabledView({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.lock_outline_rounded,
                color: AppTheme.textMuted,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            if (title != null && title!.isNotEmpty) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(actionLabel ?? 'Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Offline Component
// ---------------------------------------------------------------------------
class UiOfflineView extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const UiOfflineView({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.warningSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.warningBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppTheme.warning,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title ?? 'Offline',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message ?? 'Network connection is required.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(retryLabel ?? 'Reconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
