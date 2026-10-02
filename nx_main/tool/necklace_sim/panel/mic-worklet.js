class NecklaceMic extends AudioWorkletProcessor {
  constructor() {
    super(); this.buffer = new Int16Array(1600); this.offset = 0;
    this.port.onmessage = ({data}) => {
      if (data !== 'flush') return;
      if (this.offset) {
        const tail = this.buffer.slice(0, this.offset);
        this.port.postMessage(tail.buffer, [tail.buffer]);
        this.offset = 0;
      }
      this.port.postMessage({flushed: true});
    };
  }
  process(inputs) {
    const input = inputs[0]?.[0];
    if (!input) return true;
    for (const sample of input) {
      this.buffer[this.offset++] = Math.round(Math.max(-1, Math.min(1, sample)) * 32767);
      if (this.offset === this.buffer.length) {
        this.port.postMessage(this.buffer.buffer, [this.buffer.buffer]);
        this.buffer = new Int16Array(1600); this.offset = 0;
      }
    }
    return true;
  }
}
registerProcessor('necklace-mic', NecklaceMic);
