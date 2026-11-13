import os
print('kaggle input:', os.listdir('/kaggle/input') if os.path.exists('/kaggle/input') else None)
for root in ['/content', '/root']:
    if os.path.exists(root):
        print(root, '->', os.listdir(root))
