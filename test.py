import tensorflow as tf
from tensorflow.keras.datasets import mnist
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Flatten, Dropout
from tensorflow.keras.utils import to_categorical
import matplotlib.pyplot as plt

# 加载MNIST数据集
print("加载MNIST数据集...")
(x_train, y_train), (x_test, y_test) = mnist.load_data()

# 数据预处理
print("数据预处理...")
# 将像素值归一化到0-1之间
x_train = x_train / 255.0
x_test = x_test / 255.0

# 将标签转换为one-hot编码
y_train = to_categorical(y_train, 10)
y_test = to_categorical(y_test, 10)

# 查看数据集形状
print(f"训练集形状: x_train={x_train.shape}, y_train={y_train.shape}")
print(f"测试集形状: x_test={x_test.shape}, y_test={y_test.shape}")

# 定义神经网络模型
print("构建神经网络模型...")
model = Sequential([
    Flatten(input_shape=(28, 28)),  # 将28x28的图像展平为784维向量
    Dense(128, activation='relu'),  # 隐藏层1，128个神经元
    Dropout(0.2),  # 防止过拟合
    Dense(64, activation='relu'),   # 隐藏层2，64个神经元
    Dense(10, activation='softmax') # 输出层，10个神经元对应10个数字
])

# 编译模型
print("编译模型...")
model.compile(optimizer='adam',
              loss='categorical_crossentropy',
              metrics=['accuracy'])

# 查看模型结构
print("模型结构:")
model.summary()

# 训练模型
print("训练模型...")
history = model.fit(x_train, y_train, epochs=10, batch_size=32, validation_split=0.2)

# 评估模型
print("评估模型...")
test_loss, test_acc = model.evaluate(x_test, y_test, verbose=2)
print(f"测试准确率: {test_acc:.4f}")

# 绘制训练过程
print("绘制训练过程...")
plt.figure(figsize=(12, 4))

# 绘制准确率
plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='训练准确率')
plt.plot(history.history['val_accuracy'], label='验证准确率')
plt.title('模型准确率')
plt.xlabel(' epoch')
plt.ylabel('准确率')
plt.legend()

# 绘制损失
plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='训练损失')
plt.plot(history.history['val_loss'], label='验证损失')
plt.title('模型损失')
plt.xlabel('epoch')
plt.ylabel('损失')
plt.legend()

plt.tight_layout()
plt.savefig('training_history.png')
print("训练历史已保存为 training_history.png")

# 预测几个测试样本
print("预测测试样本...")
import numpy as np

# 随机选择5个测试样本
random_indices = np.random.choice(len(x_test), 5, replace=False)
test_samples = x_test[random_indices]
test_labels = y_test[random_indices]

# 进行预测
predictions = model.predict(test_samples)
predicted_labels = np.argmax(predictions, axis=1)
actual_labels = np.argmax(test_labels, axis=1)

# 显示预测结果
print("预测结果:")
print(f"实际标签: {actual_labels}")
print(f"预测标签: {predicted_labels}")

# 保存模型
print("保存模型...")
model.save('digit_recognition_model.h5')
print("模型已保存为 digit_recognition_model.h5")

print("数字神经网络识别模型实现完成！")