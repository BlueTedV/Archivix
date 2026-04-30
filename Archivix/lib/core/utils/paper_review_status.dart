import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

abstract class PaperReviewStatus {
  static const String draft = 'draft';
  static const String submitted = 'submitted';
  static const String underReview = 'under_review';
  static const String published = 'published';
  static const String rejected = 'rejected';

  static const List<String> reviewQueueStatuses = <String>[
    submitted,
    underReview,
  ];

  static const List<String> editableStatuses = <String>[
    draft,
    submitted,
    underReview,
    rejected,
  ];

  static String normalize(dynamic rawStatus) {
    final normalized = '$rawStatus'.trim().toLowerCase();
    switch (normalized) {
      case draft:
      case submitted:
      case underReview:
      case published:
      case rejected:
        return normalized;
      case 'under review':
        return underReview;
      default:
        return draft;
    }
  }

  static bool isPublished(dynamic status) => normalize(status) == published;

  static bool isOwnerEditable(dynamic status) {
    return editableStatuses.contains(normalize(status));
  }

  static String label(dynamic status) {
    switch (normalize(status)) {
      case draft:
        return 'Draft';
      case submitted:
        return 'Submitted';
      case underReview:
        return 'Under Review';
      case published:
        return 'Published';
      case rejected:
        return 'Rejected';
      default:
        return 'Draft';
    }
  }

  static String ownerDescription(dynamic status) {
    switch (normalize(status)) {
      case draft:
        return 'Only you can see this draft right now.';
      case submitted:
        return 'Waiting for admin review before it appears publicly.';
      case underReview:
        return 'An admin is currently reviewing this document.';
      case published:
        return 'This document is live and visible in the public feed.';
      case rejected:
        return 'This document needs changes before it can be published.';
      default:
        return 'This document is still in progress.';
    }
  }

  static Color textColor(dynamic status) {
    switch (normalize(status)) {
      case draft:
        return AppColors.textSecondary;
      case submitted:
        return AppColors.amberDark;
      case underReview:
        return AppColors.slatePrimary;
      case published:
        return AppColors.successDark;
      case rejected:
        return AppColors.errorDark;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color backgroundColor(dynamic status) {
    switch (normalize(status)) {
      case draft:
        return AppColors.surfaceLight;
      case submitted:
        return AppColors.amberSurface;
      case underReview:
        return const Color(0xFFE9EFF7);
      case published:
        return AppColors.successLight;
      case rejected:
        return AppColors.errorSurface;
      default:
        return AppColors.surfaceLight;
    }
  }

  static Color borderColor(dynamic status) {
    switch (normalize(status)) {
      case draft:
        return AppColors.border;
      case submitted:
        return AppColors.amberBorder;
      case underReview:
        return const Color(0xFFB9C6D8);
      case published:
        return const Color(0xFF6EE7B7);
      case rejected:
        return AppColors.errorBorder;
      default:
        return AppColors.border;
    }
  }

  static IconData icon(dynamic status) {
    switch (normalize(status)) {
      case draft:
        return Icons.edit_note_outlined;
      case submitted:
        return Icons.upload_file_outlined;
      case underReview:
        return Icons.fact_check_outlined;
      case published:
        return Icons.verified_outlined;
      case rejected:
        return Icons.cancel_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
