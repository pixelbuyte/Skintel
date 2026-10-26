import sys
from rembg import remove, new_session
from PIL import Image
sess = new_session(sys.argv[1])
for src, dst in zip(sys.argv[2::2], sys.argv[3::2]):
    im = Image.open(src).convert('RGB')
    out = remove(im, session=sess, post_process_mask=True)
    out.save(dst); print('saved', dst, out.size)
