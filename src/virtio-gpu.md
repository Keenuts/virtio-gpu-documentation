# Virtio-GPU | Virgl3D commands

 This document won't explain how to send a basic virtio-gpu command.
 Virtio-gpu documentation can be found [HERE](https://www.kraxel.org/virtio/virtio-v1.0-cs03-virtio-gpu.pdf)
 However, I will try to document Virgl3D related commands and every aspect virtio-gpu documentation does not cover today (June, 8th 2017).

\pagebreak

## Reminders

```C
struct iovec {
    void *iov_base;
    size_t iov_len;
};

typedef struct VirtQueueElement
{
    unsigned int index;
    unsigned int out_num;
    unsigned int in_num;
    hwaddr *in_addr;
    hwaddr *out_addr;
    struct iovec *in_sg;
    struct iovec *out_sg;
} VirtQueueElement;

struct virtio_gpu_ctrl_hdr {
	uint32_t type;
	uint32_t flags;
	uint64_t fence_id;
	uint32_t ctx_id;
	uint32_t padding;
};

struct virtio_gpu_ctrl_command {
    VirtQueueElement elem;
    VirtQueue *vq;
    struct virtio_gpu_ctrl_hdr cmd_hdr;
    uint32_t error;
    bool waiting; //OUT
    bool finished; //OUT
    QTAILQ_ENTRY(virtio_gpu_ctrl_command) next; next cmd
};
```

\pagebreak

## VIRTIO_GPU_CMD_CTX_CREATE

```C
    uint32_t nlen
    uint32_t padding
    char[64] debug_name
```

This is a Virgl context. To split resources between process, etc.
This is NOT an OpenGL context.

- Context number must be != 0. 0 is a special context value.
- Max context number is defined by **VREND_MAX_CTX** (16)
- id nlen is != 0, 64 chars from debug_name len will copied to ctx name.

\pagebreak

## VIRTIO_GPU_CMD_CTX_DESTROY:
No specific parameters

\pagebreak

## VIRTIO_GPU_CMD_SUBMIT_3D:

3D command decoder is called from QEMU with a buffer, a context ID, and a word count.
After the usual header, you will put the actual 3D commands.

- Context must be valid
- Context must be lower than **VREND_MAX_CTX** (16)

Like every commands, cmd.header.ctx_id must be set to the virgl context id.
cmd.header.type will be VIRTIO_GPU_CMD_SUBMIT_3D.
cmd.len is the length of your commandbuffer in bytes.

This command buffer can contain several 3D commands.
Each command is composed of a header, and a payload.

| uint16_t (MSB)| uint16_t (LSB)|
|------|-------|
|Length|Command|


By example, to create a context (**with ctx id=5**)and then set it as current, I could issue the following command buffer:

| 32 bits |
|:------:|
| VIRTIO_CCMD_CREATE_SUB_CTX \| (4 << 16) |
|5|
| VIRTIO_CCMD_SET_SUB_CTX \| (4 << 16) |
|5|

    cell[0] = command + length of the payload (1 uint32_t -> 4 bytes)
    cell[1] = context ID
    ...

These are the type allowed

```C
enum {
   VIRGL_CCMD_NOP = 0,
   VIRGL_CCMD_CREATE_OBJECT = 1,
   VIRGL_CCMD_BIND_OBJECT,
   VIRGL_CCMD_DESTROY_OBJECT,
   VIRGL_CCMD_SET_VIEWPORT_STATE,
   VIRGL_CCMD_SET_FRAMEBUFFER_STATE,
   VIRGL_CCMD_SET_VERTEX_BUFFERS,
   VIRGL_CCMD_CLEAR,
   VIRGL_CCMD_DRAW_VBO,
   VIRGL_CCMD_RESOURCE_INLINE_WRITE,
   VIRGL_CCMD_SET_SAMPLER_VIEWS,
   VIRGL_CCMD_SET_INDEX_BUFFER,
   VIRGL_CCMD_SET_CONSTANT_BUFFER,
   VIRGL_CCMD_SET_STENCIL_REF,
   VIRGL_CCMD_SET_BLEND_COLOR,
   VIRGL_CCMD_SET_SCISSOR_STATE,
   VIRGL_CCMD_BLIT,
   VIRGL_CCMD_RESOURCE_COPY_REGION,
   VIRGL_CCMD_BIND_SAMPLER_STATES,
   VIRGL_CCMD_BEGIN_QUERY,
   VIRGL_CCMD_END_QUERY,
   VIRGL_CCMD_GET_QUERY_RESULT,
   VIRGL_CCMD_SET_POLYGON_STIPPLE,
   VIRGL_CCMD_SET_CLIP_STATE,
   VIRGL_CCMD_SET_SAMPLE_MASK,
   VIRGL_CCMD_SET_STREAMOUT_TARGETS,
   VIRGL_CCMD_SET_RENDER_CONDITION,
   VIRGL_CCMD_SET_UNIFORM_BUFFER,

   VIRGL_CCMD_SET_SUB_CTX,
   VIRGL_CCMD_CREATE_SUB_CTX,
   VIRGL_CCMD_DESTROY_SUB_CTX,
   VIRGL_CCMD_BIND_SHADER
}
```

\pagebreak

### VIRGL_CCMD_CLEAR

parameters = 6
```C
[0] (uint32_t) Buffer index
[1] (uint32_t) R
[2] (uint32_t) G
[3] (uint32_t) B
[4] (uint32_t) A
[5] (double (64 bits)) Depth
[6] (uint32_t) stencil
```
Note: On Windows, float are disabled in the kernel (DKM).

### VIRGL_CCMD_FLUSH

### VIRGL_CCMD_SET_VIEWPORT_STATE

This command takes an array and a starting offset.
If the offset 'n', with n > 0, first n values are skipped.

Each viewport is defined using 6 32-bit floats. 3 for the scale, 3 for the translation
Here is an example with 1 viewport, and offset 0.

parameters = 7;
```C
[0] (uint32_t) offset = 0
[1] (float (32 bits)) scale_A = 1.0f
[2] (float (32 bits)) scale_B = 1.0f
[3] (float (32 bits)) scale_C = 1.0f
[4] (float (32 bits)) translation_A = 0.0f
[5] (float (32 bits)) translation_B = 0.0f
[6] (float (32 bits)) translation_C = 0.0f
```

### VIRGL_CCMD_SET_SUB_CTX

parameters = 1
```C
[0] (uint32_t) context_id
```

### VIRGL_CCMD_CREATE_SUB_CTX

parameters = 1
```C
[0] (uint32_t) context_id
```

### VIRGL_CCMD_DESTROY_SUB_CTX

parameters = 1
```C
[0] (uint32_t) context_id
```
