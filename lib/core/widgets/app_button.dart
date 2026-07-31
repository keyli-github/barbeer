import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, danger, outline, text }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final AppButtonVariant variant;
  final double height;
  const AppButton({super.key, required this.label, this.onPressed, this.isLoading=false,
      this.isFullWidth=false, this.icon, this.variant=AppButtonVariant.primary, this.height=52});
  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2.5,
              valueColor:AlwaysStoppedAnimation(variant==AppButtonVariant.outline?AppColors.primary:Colors.white)))
        : icon!=null ? Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:18),const SizedBox(width:8),Text(label)])
        : Text(label) as Widget;
    Widget btn;
    switch(variant){
      case AppButtonVariant.danger:
        btn=ElevatedButton(onPressed:isLoading?null:onPressed,
            style:ElevatedButton.styleFrom(backgroundColor:AppColors.error,foregroundColor:Colors.white),child:child); break;
      case AppButtonVariant.outline:
        btn=OutlinedButton(onPressed:isLoading?null:onPressed,child:child); break;
      case AppButtonVariant.text:
        btn=TextButton(onPressed:isLoading?null:onPressed,child:child); break;
      default:
        btn=ElevatedButton(onPressed:isLoading?null:onPressed,child:child);
    }
    return isFullWidth ? SizedBox(width:double.infinity,height:height,child:btn) : SizedBox(height:height,child:btn);
  }
}

class PrimaryButton extends StatelessWidget {
  final String label; final VoidCallback? onPressed; final bool isLoading; final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.isLoading=false, this.icon});
  @override
  Widget build(BuildContext context) =>
      AppButton(label:label,onPressed:onPressed,isLoading:isLoading,isFullWidth:true,icon:icon,height:54);
}
