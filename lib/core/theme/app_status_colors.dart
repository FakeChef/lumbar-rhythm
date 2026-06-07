import 'package:flutter/material.dart';

import 'app_colors.dart';

enum AppStatusTone {
  normal,
  nearReminder,
  overtime,
  overtimeWithDiscomfort,
  walkingOrResting,
}

class AppStatusColors {
  const AppStatusColors._();

  static Color colorFor(AppStatusTone tone) {
    return switch (tone) {
      AppStatusTone.normal => AppColors.primaryBlue,
      AppStatusTone.nearReminder => AppColors.nearReminderYellow,
      AppStatusTone.overtime => AppColors.overtimeOrange,
      AppStatusTone.overtimeWithDiscomfort => AppColors.discomfortRedOrange,
      AppStatusTone.walkingOrResting => AppColors.stableGreen,
    };
  }
}
