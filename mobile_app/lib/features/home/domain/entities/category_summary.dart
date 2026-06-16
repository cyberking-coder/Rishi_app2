class CategorySummary {
  final String id;
  final String name;
  final String slug;

  const CategorySummary({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory CategorySummary.fromMap(Map<String, dynamic> map) =>
      CategorySummary(
        id: map['id'] as String,
        name: map['name'] as String,
        slug: map['slug'] as String,
      );
}
