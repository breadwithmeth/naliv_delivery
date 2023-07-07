import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/misc/api.dart';

class LikeButton extends StatefulWidget {
  const LikeButton({super.key, this.is_liked, required this.item_id});
  final String? is_liked;
  final String item_id;
  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool is_liked = false;
  @override
  void initState() {
    // TODO: implement initState
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
            child: Icon(Icons.favorite),
            onTap: () async {
              String? _is_liked = await dislikeItem(widget.item_id);
              if (_is_liked != null) {
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
        : GestureDetector(onTap: () async {
              String? _is_liked = await likeItem(widget.item_id);
              if (_is_liked != null) {
                setState(() {
                  is_liked = true;
                });
              } else {
                setState(() {
                  is_liked = false;
                });
              }
            }, child: Icon(Icons.favorite_outline));
  }
}
