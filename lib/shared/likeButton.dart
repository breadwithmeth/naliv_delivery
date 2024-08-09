import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';

class LikeButton extends StatefulWidget {
  const LikeButton({super.key, this.is_liked, required this.item_id});
  final String? is_liked;
  final dynamic item_id;
  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool is_liked = false;
  @override
  void initState() {
    super.initState();
    if (widget.is_liked != null) {
      setState(() {
        is_liked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return is_liked
        ? GestureDetector(
            // style: IconButton.styleFrom(padding: EdgeInsets.all(0)),
            child: const Icon(Icons.favorite),
            onTap: () async {
              String? isLiked1 = await dislikeItem(widget.item_id);
              if (isLiked1 != null) {
                setState(() {
                  is_liked = true;
                });
              } else {
                setState(() {
                  is_liked = false;
                });
              }
            },
          )
        : GestureDetector(
            onTap: () async {
              String? isLiked = await likeItem(widget.item_id);
              if (isLiked != null) {
                setState(() {
                  is_liked = true;
                });
              } else {
                setState(() {
                  is_liked = false;
                });
              }
            },
            child: const Icon(Icons.favorite_outline));
  }
}
