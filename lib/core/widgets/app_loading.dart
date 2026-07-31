import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppLoading extends StatelessWidget {
  final String? message; const AppLoading({super.key,this.message});
  @override Widget build(BuildContext context) => Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const CircularProgressIndicator(color:AppColors.primary,strokeWidth:2.5),
    if(message!=null)...[const SizedBox(height:16),Text(message!,style:AppTextStyles.bodyMedium,textAlign:TextAlign.center)],
  ]));
}
class InlineLoader extends StatelessWidget {
  final double size; final Color? color; const InlineLoader({super.key,this.size=20,this.color});
  @override Widget build(BuildContext context) => SizedBox(width:size,height:size,
    child:CircularProgressIndicator(strokeWidth:2,color:color??AppColors.primary));
}
