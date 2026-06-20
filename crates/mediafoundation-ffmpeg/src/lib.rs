#![cfg(windows)]

mod audio;
mod h264;

pub use audio::AudioExt;
pub use h264::{set_fragmented_mp4_options, H264StreamMuxer, MuxerConfig};
