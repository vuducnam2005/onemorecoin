import 'dart:math';

import 'package:flutter/material.dart';

class CustomLinearProgressIndicator extends StatefulWidget {
  const CustomLinearProgressIndicator({
    Key? key,
    this.color = Colors.green,
    this.colors = const [Colors.green, Colors.red],
    this.backgroundColor = Colors.grey,
    this.maxProgressWidth = 100,
    this.value = 0.0,
    this.height = 10,
  }) : super(key: key);

  /// max width in center progress
  final double maxProgressWidth;

  final Color color;
  final List<Color> colors;
  final Color backgroundColor;
  final double value;
  final int height;

  @override
  State<CustomLinearProgressIndicator> createState() =>
      _CustomLinearProgressIndicatorState();
}

class _CustomLinearProgressIndicatorState extends State<CustomLinearProgressIndicator>{


  @override
  void initState() {
    super.initState();
  
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    Color color = widget.colors[0];
    if (widget.colors.length > 1) {
      color = Color.lerp(widget.colors[0], widget.colors[1], widget.value / widget.maxProgressWidth)!;
    }
    return Center(
        child: Column(
          children: [
            Stack(children: <Widget>[
              Container(
                height: widget.height.toDouble(),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.0),
                  color: widget.backgroundColor,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: min((widget.value / widget.maxProgressWidth), 1.0),
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15.0),
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
             
            ]),
           
          ],
        )
    );
  }
}


class TicketClipper extends CustomClipper<Path> {

  @override
  Path getClip(Size size) {

    // ve mui ten
    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height / 4),const Radius.circular(0),
    ));
    final clipPath = Path();
    clipPath.moveTo(size.width/2, 0.0);
    clipPath.lineTo(size.width * 0.65, size.height / 4);
    clipPath.lineTo(size.width * 0.35, size.height / 4);
    // combine two path together
    final ticketPath = Path.combine(
      PathOperation.intersect,
      clipPath,
      path,
    );

    // ve hinh chu nhat
    final path2 = Path();
    path2.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 4, size.width, size.height * 0.75),const Radius.circular(0),
    ));

    final ticketPath2 = Path.combine(
      PathOperation.union,
      ticketPath,
      path2,
    );

    return ticketPath2;

    return path;
  }

  @override
  bool shouldReclip(TicketClipper oldClipper) => false;
}
