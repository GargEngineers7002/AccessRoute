import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/geocoding_service.dart';

/// Autocomplete search bar widget for locating places and local campus presets.
class PlaceSearchBar extends StatefulWidget {
  /// Creates a [PlaceSearchBar].
  const PlaceSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.userLocation,
    this.currentDestinationName,
    this.onClear,
  });

  /// Callback when a place suggestion is selected.
  final ValueChanged<PlaceSuggestion> onPlaceSelected;

  /// Current user location for distance calculation & geo-bias.
  final LatLng? userLocation;

  /// Currently active destination name if routed.
  final String? currentDestinationName;

  /// Callback when user clears search or route.
  final VoidCallback? onClear;

  @override
  State<PlaceSearchBar> createState() => _PlaceSearchBarState();
}

class _PlaceSearchBarState extends State<PlaceSearchBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _geocodingService = GeocodingService();
  Timer? _debounceTimer;

  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentDestinationName != null) {
      _textController.text = widget.currentDestinationName!;
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _onQueryChanged(_textController.text);
      } else {
        // Small delay so item taps can register before closing
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_focusNode.hasFocus) {
            setState(() => _isDropdownOpen = false);
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlaceSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentDestinationName != oldWidget.currentDestinationName) {
      if (widget.currentDestinationName != null && !_focusNode.hasFocus) {
        _textController.text = widget.currentDestinationName!;
      } else if (widget.currentDestinationName == null && !_focusNode.hasFocus) {
        _textController.clear();
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = GeocodingService.campusPresets;
        _isDropdownOpen = _focusNode.hasFocus;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isDropdownOpen = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _geocodingService.searchPlaces(
        query,
        userLocation: widget.userLocation,
      );
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    });
  }

  void _selectPlace(PlaceSuggestion place) {
    _textController.text = place.name;
    setState(() => _isDropdownOpen = false);
    _focusNode.unfocus();
    widget.onPlaceSelected(place);
  }

  void _clearSearch() {
    _textController.clear();
    setState(() {
      _suggestions = [];
      _isDropdownOpen = false;
    });
    _focusNode.unfocus();
    widget.onClear?.call();
  }

  String _formatDistance(LatLng destination) {
    final ref = widget.userLocation ?? GeocodingService.campusCenter;
    const calc = Distance();
    final meters = calc.as(LengthUnit.Meter, ref, destination);
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Input Card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B2838).withAlpha(245),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focusNode.hasFocus ? const Color(0xFF42A5F5) : Colors.white12,
              width: _focusNode.hasFocus ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14, right: 10),
                child: Icon(Icons.search, color: Color(0xFF42A5F5), size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  onChanged: _onQueryChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Search place (e.g. "Library", "Gate")...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF42A5F5)),
                  ),
                ),
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: _clearSearch,
                ),
            ],
          ),
        ),

        // Dropdown Suggestions
        if (_isDropdownOpen && (_suggestions.isNotEmpty || _isLoading))
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2838).withAlpha(250),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const Divider(
                  color: Colors.white10,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final place = _suggestions[index];
                  final distance = _formatDistance(place.location);

                  return InkWell(
                    onTap: () => _selectPlace(place),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: place.isCampusPreset
                                  ? const Color(0xFF1565C0).withAlpha(60)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              place.isCampusPreset
                                  ? Icons.school
                                  : Icons.location_on_outlined,
                              color: place.isCampusPreset
                                  ? const Color(0xFF42A5F5)
                                  : Colors.white70,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        place.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (place.isCampusPreset) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF42A5F5).withAlpha(40),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Campus',
                                          style: TextStyle(
                                            color: Color(0xFF90CAF9),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  place.subtitle,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            distance,
                            style: const TextStyle(
                              color: Color(0xFF4FC3F7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
