class AppUser {
  final String id;
  final String email;
  final String? displayName;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
  });
}
