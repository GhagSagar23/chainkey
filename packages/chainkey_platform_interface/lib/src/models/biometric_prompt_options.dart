/// Configuration options for system biometric authentication prompts.
class BiometricPromptOptions {
  const BiometricPromptOptions({
    this.title = 'Biometric Authentication',
    this.subtitle,
    this.description,
    this.negativeButtonText = 'Cancel',
    this.confirmationRequired = true,
  });

  /// The title displayed in the biometric prompt.
  final String title;

  /// The subtitle displayed in the biometric prompt.
  final String? subtitle;

  /// Detailed description explaining the transaction to be signed.
  final String? description;

  /// The label for the cancel or negative button.
  final String negativeButtonText;

  /// Whether explicit confirmation (e.g. tapping "Confirm" after Face ID / biometric scan) is required.
  final bool confirmationRequired;

  Map<String, dynamic> toMap() => {
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'negativeButtonText': negativeButtonText,
        'confirmationRequired': confirmationRequired,
      };

  factory BiometricPromptOptions.fromMap(Map<String, dynamic> map) {
    return BiometricPromptOptions(
      title: map['title'] as String? ?? 'Biometric Authentication',
      subtitle: map['subtitle'] as String?,
      description: map['description'] as String?,
      negativeButtonText: map['negativeButtonText'] as String? ?? 'Cancel',
      confirmationRequired: map['confirmationRequired'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiometricPromptOptions &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          subtitle == other.subtitle &&
          description == other.description &&
          negativeButtonText == other.negativeButtonText &&
          confirmationRequired == other.confirmationRequired;

  @override
  int get hashCode =>
      title.hashCode ^
      subtitle.hashCode ^
      description.hashCode ^
      negativeButtonText.hashCode ^
      confirmationRequired.hashCode;

  @override
  String toString() {
    return 'BiometricPromptOptions(title: $title, subtitle: $subtitle, description: $description, negativeButtonText: $negativeButtonText, confirmationRequired: $confirmationRequired)';
  }
}
