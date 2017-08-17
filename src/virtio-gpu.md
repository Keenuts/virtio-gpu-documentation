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

## VIRTIO_GPU_CMD_RESOURCE_CREATE_2D

3D and 2D resource creation are the same under the hood.
The main difference are default values. Thus a lightweight command for 2D.

```C
struct {
  uint32_t handle;
  //target is set to 2
  uint32_t format;
  //bind is set to 2
  uint32_t width;
  uint32_t height;
  //depth = 1
  //array_size = 1
  //last_level = 0
  //nr_samples = 0
  //flags = VIRTIO_GPU_RESOURCE_FLAG_Y_0_TOP
};
```

\pagebreak

## VIRTIO_GPU_CMD_RESOURCE_CREATE_3D

This time, no default values, we need to setup all the fields

```C
struct {
  uint32_t handle;
  uint32_t target;
  uint32_t format;
  uint32_t bind;
  uint32_t width;
  uint32_t height;
  uint32_t depth;
  uint32_t array_size;
  uint32_t last_level;
  uint32_t nr_samples;
  uint32_t flags;
	uint32_t padding;
};
```

\pagebreak

## VIRTIO_GPU_CMD_CTX_ATTACH_RESOURCE

Once a resource has been created, we need to attach it to a VGL context.
Once attached, we will be able to use it.

Remember: virgl context is already given in the command header.

```C
struct {
  uint32_t handle;
  uint32_t padding;
};
```

\pagebreak

## VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING

Once the resource created and attached, we may want modyfy/set it.
There is two methods: INLINE_WRITE, or backing attachment.

backing attachment is a way to share memory pages.
Guest will send physical pages addresses, and host will link these pages to the resource.

First, we find the header, describing how many entries we want to register, and a handle.
Then, we will one field per entries, describing the size and start of the entry.

```C
//Command head
struct {
  uint32_t resource_id;
  uint32_t nr_entries;
};

//One entry description
struct {
  uint64_t address;
  uint32_t length;
  uint32_t padding; //struct padding, non related to our entry
};
```

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

| uint32_t (MSB)| uint32_t (LSB)|
|------|-------|
|Length|Command|


By example, to create a context (**with ctx id=5**)and then set it as current, I could issue the following command buffer:

| 32 bits |
|:------:|
| 4 (Payload length = 4 bytes) |
| VIRTIO_CCMD_CREATE_SUB_CTX (command) |
| 5 (payload[0]) |
| 4 (payload length = 4 bytes) |
| VIRTIO_CCMD_SET_SUB_CTX (command)|
|5 (payload[0] |

    cell[0] = command + length of the payload (1 uint32_t --> payload = 4)
    cell[1] = context ID
    ...

\pagebreak

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

## VIRGL_CCMD_CLEAR

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

\pagebreak

## VIRGL_CCMD_DRAW_VBO

parameters = 12
```C
[0] (uint32_t) indexed //is rendering indexed ?
[1] (uint32_t) mode    //GLEnum GL_TRIANGLE/GL_LINE/etc...

[2] (uint32_t) start
[3] (uint32_t) count

[4] (uint32_t) start_instance // Only if instance rendering is enabled
[5] (uint32_t) instance_count

[6] (uint32_t) index_bias //Only if indexed rendering is set
[7] (uint32_t) min_index
[8] (uint32_t) max_index

[9] (uint32_t) primitive_restart
[10] (uint32_t) restart_index

[11] (uint32_t) cso // If != 0, will be used as count, and start will be 0.
```

\pagebreak

## VIRGL_CCMD_CREATE_OBJECT

Object creation parameters are higly dependent of the type of objects you create.
However, the first parameter is always the handle.

To specify the object type, you need to define the '**opt**' field of the header to the desired type.

\pagebreak

### Creating VIRGL_OBJECT_BLEND

```C
[0] (uint32_t)  Handle (as always)
[1] bitfield_1
[2] bitfield_2
[3] bitfield_3
...
[10] bitfield_3
```

#### bitfield 1
```C
// LSB on top
struct {
  uint8_t independant_blend_enable : 1;
  uint8_t logicop_enable : 1;
  uint8_t dither : 1;
  uint8_t alpha_to_coverage : 1;
  uint8_t alpha_to_one : 1;
};
```

#### bitfield 2
```C
// LSB on top
struct {
  uint8_t logicop_func : 4;
};
```

#### bitfield 3
```C
// LSB on top
struct {
  uint8_t blend_enable : 1;
  uint8_t rgb_func : 3;
  uint8_t rgb_src_factor : 5;
  uint8_t rgb_dst_factor : 5;
  uint8_t alpha_func : 3;
  uint8_t alpha_src_factor : 5;
  uint8_t alpha_dst_factor : 5;
  uint8_t colormask : 4;
};
```

\pagebreak

### Creating VIRGL_OBJECT_RASTERIZER

There is 9 parameters

```C
[0] (uint32_t)  Handle (as always)
[1] (uint32_t)  bitfield 1
[2] (float)     Point size 
[3] (uint32_t)  Sprit coord enabled ?
[4] (uint32_t)  bitfield 2
[5] (float)     Line width
[6] (float)     offset units
[7] (float)     offset scale
[8] (float)     offset clamp
```

#### Bitfield 1
```C
//LSB on top
// All are 1 bit width except when specified otherwise
struct {
  uint8_t flatshade;
  uint8_t depth_clip;
  uint8_t clip_halfz;
  uint8_t rasterizer_discard;
  uint8_t flatshade_first;
  uint8_t light_twoside;
  uint8_t sprit_coord_mode;
  uint8_t point_quad_rasterization;
  uint8_t cull_face : 2;
  uint8_t fill_front : 2;
  uint8_t fill_back : 2;
  uint8_t scissor;
  uint8_t front_ccw;
  uint8_t clamp_vertex_color;
  uint8_t clamp_fragment_color;
  uint8_t offset_line;
  uint8_t offset_point;
  uint8_t offset_tri;
  uint8_t poly_smooth;
  uint8_t poly_stipple_enable;
  uint8_t point_smooth;
  uint8_t point_size_per_vertex;
  uint8_t multisample;
  uint8_t line_smooth;
  uint8_t line_stipple:enable;
  uint8_t line_last_pixel;
  uint8_t half_pixel_center;
  uint8_t bottom_edge_rule;
};
```

#### bitfield 2
```C
#define PIPE_MAX_CLIP_PLANES 8

//LSB on top
struct {
  uint16_t line_stipple_pattern : 16
  uint16_t line_stipple_factor : 8
  uint16_t clip_plane_enable : PIPE_MAX_CLIP_PLANES
};
```

\pagebreak

### Creating VIRGL_OBJECT_SHADER

To create a shader, parameters are the following:

parameters = 5 + nb_tokens / 4
```C
[0] Handle (as always)
[1] Shader type (0 = vertex, 1 = fragment)
[2] number of tokens (aka how many letters in the ASCII representation)
[3] offlen seam to be the offset to the 1st instruction (roughly)
[4] num_so_output : stream output count
[5] -> [END] Your shader, in TGSI-ASCII stored in a UINT32[]
```

\pagebreak

### Creating VIRGL_OBJECT_SURFACE

To create a surface, parameters are the following:

parameters = 5
```C
[0] Handle (as always)
[1] resource handle
[2] format
[3] val0 //dependent of the surface type
[4] val1 //dependent of the surface type
```

\pagebreak

### Creating VIRGL_OBJECT_DSA

To create a DSA, parameters are the following (parameters = 5):
```C
[0] Handle (as always)
[1] bitfield 1
[2] bitfield 2
[3] bitfield 2
[4] alpha ref
```

#### bitfield 1
```C
//LSB on top
struct {
  uint16_t depth_enabled : 1
  uint16_t depth_writemask : 1
  uint16_t depth_func : 3
  uint16_t unused : 3
  uint16_t alpha_enabled : 1
  uint16_t alpha_func : 3
};
```

#### bitfield 2
```C
//LSB on top
struct {
  uint16_t stencil_enabled : 1
  uint16_t stencil_func : 3
  uint16_t stencil_fail_op : 3
  uint16_t stencil_zpass_op : 3
  uint16_t stencil_zfail_op : 3
  uint16_t stencil_valuemask_op : 8
  uint16_t stencil_writemask_op : 8
};
```


\pagebreak

## VIRGL_CCMD_SET_VIEWPORT_STATE

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

\pagebreak

## VIRGL_CCMD_SET_SUB_CTX

Create a sub context -> OpenGL context
The created sub-context will be set as active.

parameters = 1
```C
[0] (uint32_t) context_id
```

\pagebreak

## VIRGL_CCMD_CREATE_SUB_CTX

Set a sub-context as active

parameters = 1
```C
[0] (uint32_t) context_id
```

\pagebreak

## VIRGL_CCMD_DESTROY_SUB_CTX

Destroy a sub-context

parameters = 1
```C
[0] (uint32_t) context_id
```

## VIRGL_CCMD_BIND_SHADER

Bind a shader to the pipeline (vtx, frag, etc)

parameters = 2
```C
[0] (uint32_t) handle
[1] (uint32_t) shader_type (0 = vertex, 1 = fragment)
1``
