MSG_LEN=32
def hid_send(*args, **kwargs): raise RuntimeError('Native HID exchange is required')
def chunks(data,size):
    for index in range(0,len(data),size): yield data[index:index+size]
