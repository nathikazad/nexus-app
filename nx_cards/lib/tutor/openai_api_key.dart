final class OpenAiBuildConfiguration {
  const OpenAiBuildConfiguration({
    required this.apiKey,
    required bool requiredForBuild,
  }) : assert(
         !requiredForBuild || apiKey != '',
         'OPENAI_API_KEY is required for nx_cards release builds. Pass '
         '--dart-define-from-file=../nx_modules/nx_live_agent/.env.',
       );

  final String apiKey;
}

const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');

const openAiBuildConfiguration = OpenAiBuildConfiguration(
  apiKey: openAiApiKey,
  requiredForBuild: bool.fromEnvironment('dart.vm.product'),
);
