import tensorflow as tf
import numpy as np

def make_gradcam_heatmap(img_array, model, last_conv_layer_name=None):
    """
    REAL Grad-CAM implementation - same as original but optimized
    """
    # Find the correct layer name for your model
    if last_conv_layer_name is None:
        # For MobileNetV2
        possible_layers = [
            'Conv_1',
            'out_relu',
            'conv_pw_13_relu',
            'block_16_expand_relu'
        ]
        
        for layer_name in possible_layers:
            try:
                model.get_layer(layer_name)
                last_conv_layer_name = layer_name
                print(f"[INFO] Using layer: {layer_name}")
                break
            except:
                continue
        
        if last_conv_layer_name is None:
            # Auto-detect last conv layer
            for layer in reversed(model.layers):
                if len(layer.output_shape) == 4:
                    last_conv_layer_name = layer.name
                    break
    
    # Create gradient model
    grad_model = tf.keras.models.Model(
        inputs=[model.input],
        outputs=[model.get_layer(last_conv_layer_name).output, model.output]
    )
    
    # Compute gradients
    with tf.GradientTape() as tape:
        tape.watch(img_array)
        conv_outputs, predictions = grad_model(img_array)
        
        # For binary classification
        if predictions.shape[-1] == 1:
            class_channel = predictions[:, 0]
        else:
            pred_index = tf.argmax(predictions[0])
            class_channel = predictions[:, pred_index]
    
    # Get gradients of the class output with respect to feature maps
    grads = tape.gradient(class_channel, conv_outputs)
    
    # Global average pooling of gradients
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
    
    # Weight feature maps by gradients
    conv_outputs = conv_outputs[0]
    heatmap = tf.reduce_sum(conv_outputs * pooled_grads, axis=-1)
    
    # Apply ReLU and normalize
    heatmap = tf.maximum(heatmap, 0)
    heatmap = heatmap / (tf.reduce_max(heatmap) + 1e-8)
    
    return heatmap.numpy()

# Alternative: Even more optimized version
def make_gradcam_heatmap_fast(img_array, model):
    """
    Faster but still REAL Grad-CAM - optimized for speed
    """
    last_conv_layer_name = 'Conv_1'
    
    # Create model
    grad_model = tf.keras.models.Model(
        [model.input], 
        [model.get_layer(last_conv_layer_name).output, model.output]
    )
    
    # Optimized gradient computation
    with tf.GradientTape() as tape:
        conv_outputs, predictions = grad_model(img_array)
        loss = predictions[:, 0]
    
    # Compute gradients
    grads = tape.gradient(loss, conv_outputs)
    
    # Efficient pooling and weighting
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
    heatmap = tf.reduce_sum(conv_outputs[0] * pooled_grads, axis=-1)
    heatmap = tf.nn.relu(heatmap)
    heatmap = heatmap / (tf.reduce_max(heatmap) + 1e-8)
    
    return heatmap.numpy()
