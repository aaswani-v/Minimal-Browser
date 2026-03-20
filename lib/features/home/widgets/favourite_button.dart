/// Favourite website button widget for the home screen.
///
/// Displays a circular button with the site's favicon (or a fallback icon).
/// Used in the Favourites grid. Supports tap (navigate) and long-press
/// (remove) gestures.
import 'package:flutter/material.dart';
import 'package:myapp/models/favourite.dart';

class FavouriteButton extends StatelessWidget {
  /// The favourite data (nullable when used as an "add" button).
  final Favourite? favourite;

  /// Icon to display when [favourite] is null (e.g. Icons.add).
  final IconData? icon;

  /// Called when the button is tapped.
  final VoidCallback onTap;

  /// Called when the button is long-pressed (e.g. to remove).
  final VoidCallback? onLongPress;

  const FavouriteButton({
    super.key,
    this.favourite,
    this.icon,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white70)
              : favourite != null
                  ? ClipOval(
                      child: Image.network(
                        favourite!.iconUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                            favourite!.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
