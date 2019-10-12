/*****************************************************************************

  MAME/MESS NES APU CORE

  Based on the Nofrendo/Nosefart NES N2A03 sound emulation core written by
  Matthew Conte (matt@conte.com) and redesigned for use in MAME/MESS by
  Who Wants to Know? (wwtk@mail.com)

  This core is written with the advise and consent of Matthew Conte and is
  released under the GNU Public License.  This core is freely avaiable for
  use in any freeware project, subject to the following terms:

  Any modifications to this code must be duly noted in the source and
  approved by Matthew Conte and myself prior to public submission.

  timing notes:
  master = 21477270
  2A03 clock = master/12
  sequencer = master/89490 or CPU/7457

 *****************************************************************************

   NES_APU.C

   Actual NES APU interface.

   LAST MODIFIED 02/29/2004

   - Based on Matthew Conte's Nofrendo/Nosefart core and redesigned to
     use MAME system calls and to enable multiple APUs.  Sound at this
     point should be just about 100% accurate, though I cannot tell for
     certain as yet.

     A queue interface is also available for additional speed.  However,
     the implementation is not yet 100% (DPCM sounds are inaccurate),
     so it is disabled by default.

 *****************************************************************************

   BUGFIXES:

   - Various bugs concerning the DPCM channel fixed. (Oliver Achten)
   - Fixed $4015 read behaviour. (Oliver Achten)

 *****************************************************************************/

/*
	Ported from MAME 0.120
	01/02/14
*/

#include "burnint.h"
#include "m6502_intf.h"
#include "nes_apu.h"
#include "nes_defs.h"

#define CHIP_NUM	2

#define LEFT	0
#define RIGHT	1

/* GLOBAL CONSTANTS */
#define  SYNCS_MAX1     0x20
#define  SYNCS_MAX2     0x80

/* GLOBAL VARIABLES */
struct nesapu_info
{
	apu_t   APU;			       /* Actual APUs */
	float   apu_incsize;           /* Adjustment increment */
	UINT32 samps_per_sync;        /* Number of samples per vsync */
	UINT32 buffer_size;           /* Actual buffer size in bytes */
	UINT32 real_rate;             /* Actual playback rate */
	UINT8   noise_lut[NOISE_LONG]; /* Noise sample lookup table */
	UINT32 vbl_times[0x20];       /* VBL durations in samples */
	UINT32 sync_times1[SYNCS_MAX1]; /* Samples per sync table */
	UINT32 sync_times2[SYNCS_MAX2]; /* Samples per sync table */

	// FBA-specific variables
	INT16 *stream;
	INT32 samples_per_frame;
	UINT32 (*pSyncCallback)(INT32 samples_per_frame);
	INT32 current_position;
	INT32 fill_buffer_hack;
	double gain[2];
	INT32 output_dir[2];
	INT32 bAdd;
};

static nesapu_info nesapu_chips[CHIP_NUM];

/* INTERNAL FUNCTIONS */

/* INITIALIZE WAVE TIMES RELATIVE TO SAMPLE RATE */
static void create_vbltimes(UINT32* table,const UINT8 *vbl,UINT32 rate)
{
  INT32 i;

  for (i=0;i<0x20;i++)
    table[i]=vbl[i]*rate;
}

/* INITIALIZE SAMPLE TIMES IN TERMS OF VSYNCS */
static void create_syncs(struct nesapu_info *info, UINT64 sps)
{
  INT32 i;
  UINT64 val=sps;

  for (i=0;i<SYNCS_MAX1;i++)
  {
    info->sync_times1[i]=val;
    val+=sps;
  }

  val=0;
  for (i=0;i<SYNCS_MAX2;i++)
  {
    info->sync_times2[i]=val;
    info->sync_times2[i]>>=2;
    val+=sps;
  }
}

/* INITIALIZE NOISE LOOKUP TABLE */
static void create_noise(UINT8 *buf, const INT32 bits, INT32 size)
{
   static INT32 m = 0x0011;
   INT32 xor_val, i;

   for (i = 0; i < size; i++)
   {
      xor_val = m & 1;
      m >>= 1;
      xor_val ^= (m & 1);
      m |= xor_val << (bits - 1);

      buf[i] = m;
   }
}

/* TODO: sound channels should *ALL* have DC volume decay */

/* OUTPUT SQUARE WAVE SAMPLE (VALUES FROM -16 to +15) */
static int8 apu_square(struct nesapu_info *info, square_t *chan)
{
   INT32 env_delay;
   INT32 sweep_delay;
   int8 output;

   /* reg0: 0-3=volume, 4=envelope, 5=hold, 6-7=duty cycle
   ** reg1: 0-2=sweep shifts, 3=sweep inc/dec, 4-6=sweep length, 7=sweep on
   ** reg2: 8 bits of freq
   ** reg3: 0-2=high freq, 7-4=vbl length counter
   */

   if (false == chan->enabled)
      return 0;

   /* enveloping */
   env_delay = info->sync_times1[chan->regs[0] & 0x0F];

   /* decay is at a rate of (env_regs + 1) / 240 secs */
   chan->env_phase -= 4;
   while (chan->env_phase < 0)
   {
      chan->env_phase += env_delay;
      if (chan->regs[0] & 0x20)
         chan->env_vol = (chan->env_vol + 1) & 15;
      else if (chan->env_vol < 15)
         chan->env_vol++;
   }

   /* vbl length counter */
   if (chan->vbl_length > 0 && 0 == (chan->regs [0] & 0x20))
      chan->vbl_length--;

   if (0 == chan->vbl_length)
      return 0;

   /* freqsweeps */
   if ((chan->regs[1] & 0x80) && (chan->regs[1] & 7))
   {
      sweep_delay = info->sync_times1[(chan->regs[1] >> 4) & 7];
      chan->sweep_phase -= 2;
      while (chan->sweep_phase < 0)
      {
         chan->sweep_phase += sweep_delay;
         if (chan->regs[1] & 8)
            chan->freq -= chan->freq >> (chan->regs[1] & 7);
         else
            chan->freq += chan->freq >> (chan->regs[1] & 7);
      }
   }

   if ((0 == (chan->regs[1] & 8) && (chan->freq >> 16) > freq_limit[chan->regs[1] & 7])
       || (chan->freq >> 16) < 4)
      return 0;

   chan->phaseacc -= (float) info->apu_incsize; /* # of cycles per sample */

   while (chan->phaseacc < 0)
   {
      chan->phaseacc += (chan->freq >> 16);
      chan->adder = (chan->adder + 1) & 0x0F;
   }

   if (chan->regs[0] & 0x10) /* fixed volume */
      output = chan->regs[0] & 0x0F;
   else
      output = 0x0F - chan->env_vol;

   if (chan->adder < (duty_lut[chan->regs[0] >> 6]))
      output = -output;

   return (int8) output;
}

/* OUTPUT TRIANGLE WAVE SAMPLE (VALUES FROM -16 to +15) */
static int8 apu_triangle(struct nesapu_info *info, triangle_t *chan)
{
   INT32 freq;
   int8 output;
   /* reg0: 7=holdnote, 6-0=linear length counter
   ** reg2: low 8 bits of frequency
   ** reg3: 7-3=length counter, 2-0=high 3 bits of frequency
   */

   if (false == chan->enabled)
      return 0;

   if (false == chan->counter_started && 0 == (chan->regs[0] & 0x80))
   {
      if (chan->write_latency)
         chan->write_latency--;
      if (0 == chan->write_latency)
         chan->counter_started = TRUE;
   }

   if (chan->counter_started)
   {
      if (chan->linear_length > 0)
         chan->linear_length--;
      if (chan->vbl_length && 0 == (chan->regs[0] & 0x80))
            chan->vbl_length--;

      if (0 == chan->vbl_length)
         return 0;
   }

   if (0 == chan->linear_length)
      return 0;

   freq = (((chan->regs[3] & 7) << 8) + chan->regs[2]) + 1;

   if (freq < 4) /* inaudible */
      return 0;

   chan->phaseacc -= (float) info->apu_incsize; /* # of cycles per sample */
   while (chan->phaseacc < 0)
   {
      chan->phaseacc += freq;
      chan->adder = (chan->adder + 1) & 0x1F;

      output = (chan->adder & 7) << 1;
      if (chan->adder & 8)
         output = 0x10 - output;
      if (chan->adder & 0x10)
         output = -output;

      chan->output_vol = output;
   }

   return (int8) chan->output_vol;
}

/* OUTPUT NOISE WAVE SAMPLE (VALUES FROM -16 to +15) */
static int8 apu_noise(struct nesapu_info *info, noise_t *chan)
{
   INT32 freq, env_delay;
   UINT8 outvol;
   UINT8 output;

   /* reg0: 0-3=volume, 4=envelope, 5=hold
   ** reg2: 7=small(93 byte) sample,3-0=freq lookup
   ** reg3: 7-4=vbl length counter
   */

   if (false == chan->enabled)
      return 0;

   /* enveloping */
   env_delay = info->sync_times1[chan->regs[0] & 0x0F];

   /* decay is at a rate of (env_regs + 1) / 240 secs */
   chan->env_phase -= 4;
   while (chan->env_phase < 0)
   {
      chan->env_phase += env_delay;
      if (chan->regs[0] & 0x20)
         chan->env_vol = (chan->env_vol + 1) & 15;
      else if (chan->env_vol < 15)
         chan->env_vol++;
   }

   /* length counter */
   if (0 == (chan->regs[0] & 0x20))
   {
      if (chan->vbl_length > 0)
         chan->vbl_length--;
   }

   if (0 == chan->vbl_length)
      return 0;

   freq = noise_freq[chan->regs[2] & 0x0F];
   chan->phaseacc -= (float) info->apu_incsize; /* # of cycles per sample */
   while (chan->phaseacc < 0)
   {
      chan->phaseacc += freq;

      chan->cur_pos++;
      if (NOISE_SHORT == chan->cur_pos && (chan->regs[2] & 0x80))
         chan->cur_pos = 0;
      else if (NOISE_LONG == chan->cur_pos)
         chan->cur_pos = 0;
   }

   if (chan->regs[0] & 0x10) /* fixed volume */
      outvol = chan->regs[0] & 0x0F;
   else
      outvol = 0x0F - chan->env_vol;

   output = info->noise_lut[chan->cur_pos];
   if (output > outvol)
      output = outvol;

   if (info->noise_lut[chan->cur_pos] & 0x80) /* make it negative */
      output = -output;

   return (int8) output;
}

/* RESET DPCM PARAMETERS */
static inline void apu_dpcmreset(dpcm_t *chan)
{
   chan->address = 0xC000 + (uint16) (chan->regs[2] << 6);
   chan->length = (uint16) (chan->regs[3] << 4) + 1;
   chan->bits_left = chan->length << 3;
   chan->irq_occurred = false;
   chan->enabled = TRUE; /* Fixed * Proper DPCM channel ENABLE/DISABLE flag behaviour*/
   chan->vol = 0; /* Fixed * DPCM DAC resets itself when restarted */
}

/* OUTPUT DPCM WAVE SAMPLE (VALUES FROM -64 to +63) */
/* TODO: centerline naughtiness */
static int8 apu_dpcm(struct nesapu_info *info, dpcm_t *chan)
{
   INT32 freq, bit_pos;

   /* reg0: 7=irq gen, 6=looping, 3-0=pointer to clock table
   ** reg1: output dc level, 7 bits unsigned
   ** reg2: 8 bits of 64-byte aligned address offset : $C000 + (value * 64)
   ** reg3: length, (value * 16) + 1
   */

   if (chan->enabled)
   {
      freq = dpcm_clocks[chan->regs[0] & 0x0F];
      chan->phaseacc -= (float) info->apu_incsize; /* # of cycles per sample */

      while (chan->phaseacc < 0)
      {
         chan->phaseacc += freq;

         if (0 == chan->length)
         {
            chan->enabled = false; /* Fixed * Proper DPCM channel ENABLE/DISABLE flag behaviour*/
            chan->vol=0; /* Fixed * DPCM DAC resets itself when restarted */
            if (chan->regs[0] & 0x40)
               apu_dpcmreset(chan);
            else
            {
               if (chan->regs[0] & 0x80) /* IRQ Generator */
               {
                  chan->irq_occurred = TRUE;
                 n2a03_irq();
               }
               break;
            }
         }


         chan->bits_left--;
         bit_pos = 7 - (chan->bits_left & 7);
         if (7 == bit_pos)
         {
            chan->cur_byte = M6502ReadByte(chan->address); //memory_read_byte(info->APU.dpcm.memory, chan->address);
            chan->address++;
            chan->length--;
         }

         if (chan->cur_byte & (1 << bit_pos))
//            chan->regs[1]++;
            chan->vol+=2; /* FIXED * DPCM channel only uses the upper 6 bits of the DAC */
         else
//            chan->regs[1]--;
            chan->vol-=2;
      }
   }

   if (chan->vol > 63)
      chan->vol = 63;
   else if (chan->vol < -64)
      chan->vol = -64;

   return (int8) (chan->vol);
}

/* WRITE REGISTER VALUE */
static inline void apu_regwrite(struct nesapu_info *info,INT32 address, UINT8 value)
{
   INT32 chan = (address & 4) ? 1 : 0;

   switch (address)
   {
   /* squares */
   case APU_WRA0:
   case APU_WRB0:
      info->APU.squ[chan].regs[0] = value;
      break;

   case APU_WRA1:
   case APU_WRB1:
      info->APU.squ[chan].regs[1] = value;
      break;

   case APU_WRA2:
   case APU_WRB2:
      info->APU.squ[chan].regs[2] = value;
      if (info->APU.squ[chan].enabled)
         info->APU.squ[chan].freq = ((((info->APU.squ[chan].regs[3] & 7) << 8) + value) + 1) << 16;
      break;

   case APU_WRA3:
   case APU_WRB3:
      info->APU.squ[chan].regs[3] = value;

      if (info->APU.squ[chan].enabled)
      {
         info->APU.squ[chan].vbl_length = info->vbl_times[value >> 3];
         info->APU.squ[chan].env_vol = 0;
         info->APU.squ[chan].freq = ((((value & 7) << 8) + info->APU.squ[chan].regs[2]) + 1) << 16;
      }

      break;

   /* triangle */
   case APU_WRC0:
      info->APU.tri.regs[0] = value;

      if (info->APU.tri.enabled)
      {                                          /* ??? */
         if (false == info->APU.tri.counter_started)
            info->APU.tri.linear_length = info->sync_times2[value & 0x7F];
      }

      break;

   case 0x4009:
      /* unused */
      info->APU.tri.regs[1] = value;
      break;

   case APU_WRC2:
      info->APU.tri.regs[2] = value;
      break;

   case APU_WRC3:
      info->APU.tri.regs[3] = value;

      /* this is somewhat of a hack.  there is some latency on the Real
      ** Thing between when trireg0 is written to and when the linear
      ** length counter actually begins its countdown.  we want to prevent
      ** the case where the program writes to the freq regs first, then
      ** to reg 0, and the counter accidentally starts running because of
      ** the sound queue's timestamp processing.
      **
      ** set to a few NES sample -- should be sufficient
      **
      **     3 * (1789772.727 / 44100) = ~122 cycles, just around one scanline
      **
      ** should be plenty of time for the 6502 code to do a couple of table
      ** dereferences and load up the other triregs
      */

	/* used to be 3, but now we run the clock faster, so base it on samples/sync */
      info->APU.tri.write_latency = (info->samps_per_sync + 239) / 240;

      if (info->APU.tri.enabled)
      {
         info->APU.tri.counter_started = false;
         info->APU.tri.vbl_length = info->vbl_times[value >> 3];
         info->APU.tri.linear_length = info->sync_times2[info->APU.tri.regs[0] & 0x7F];
      }

      break;

   /* noise */
   case APU_WRD0:
      info->APU.noi.regs[0] = value;
      break;

   case 0x400D:
      /* unused */
      info->APU.noi.regs[1] = value;
      break;

   case APU_WRD2:
      info->APU.noi.regs[2] = value;
      break;

   case APU_WRD3:
      info->APU.noi.regs[3] = value;

      if (info->APU.noi.enabled)
      {
         info->APU.noi.vbl_length = info->vbl_times[value >> 3];
         info->APU.noi.env_vol = 0; /* reset envelope */
      }
      break;

   /* DMC */
   case APU_WRE0:
      info->APU.dpcm.regs[0] = value;
      if (0 == (value & 0x80))
         info->APU.dpcm.irq_occurred = false;
      break;

   case APU_WRE1: /* 7-bit DAC */
      //info->APU.dpcm.regs[1] = value - 0x40;
      info->APU.dpcm.regs[1] = value & 0x7F;
      info->APU.dpcm.vol = (info->APU.dpcm.regs[1]-64);
      break;

   case APU_WRE2:
      info->APU.dpcm.regs[2] = value;
      //apu_dpcmreset(info->APU.dpcm);
      break;

   case APU_WRE3:
      info->APU.dpcm.regs[3] = value;
      break;

   case APU_IRQCTRL:
   	break;

   case APU_SMASK:
      if (value & 0x01)
         info->APU.squ[0].enabled = TRUE;
      else
      {
         info->APU.squ[0].enabled = false;
         info->APU.squ[0].vbl_length = 0;
      }

      if (value & 0x02)
         info->APU.squ[1].enabled = TRUE;
      else
      {
         info->APU.squ[1].enabled = false;
         info->APU.squ[1].vbl_length = 0;
      }

      if (value & 0x04)
         info->APU.tri.enabled = TRUE;
      else
      {
         info->APU.tri.enabled = false;
         info->APU.tri.vbl_length = 0;
         info->APU.tri.linear_length = 0;
         info->APU.tri.counter_started = false;
         info->APU.tri.write_latency = 0;
      }

      if (value & 0x08)
         info->APU.noi.enabled = TRUE;
      else
      {
         info->APU.noi.enabled = false;
         info->APU.noi.vbl_length = 0;
      }

      if (value & 0x10)
      {
         /* only reset dpcm values if DMA is finished */
         if (false == info->APU.dpcm.enabled)
         {
            info->APU.dpcm.enabled = TRUE;
            apu_dpcmreset(&info->APU.dpcm);
         }
      }
      else
         info->APU.dpcm.enabled = false;

      info->APU.dpcm.irq_occurred = false;

      break;
   default:
#ifdef MAME_DEBUG
logerror("invalid apu write: $%02X at $%04X\n", value, address);
#endif
      break;
   }
}

/* UPDATE SOUND BUFFER USING CURRENT DATA */
static inline void apu_update(struct nesapu_info *info)
{
   INT32 accum;

//------------------------------------------------------------------------------------------------------
	if (info->pSyncCallback == NULL) return;
	INT32 position;

	if (info->fill_buffer_hack) {
		position = info->samples_per_frame;
		info->fill_buffer_hack = 0;
	} else {
		position = info->pSyncCallback(info->samples_per_frame);
	}

	if (position > info->samples_per_frame) position = info->samples_per_frame;
	if (position == info->current_position) return;

	INT16 *buffer16 = info->stream + info->current_position;

	INT32 samples = position - info->current_position;

	info->current_position = position;

	if (samples <= 0) return;
//------------------------------------------------------------------------------------------------------

   while (samples--)
   {
      accum = apu_square(info, &info->APU.squ[0]);
      accum += apu_square(info, &info->APU.squ[1]);
      accum += apu_triangle(info, &info->APU.tri);
      accum += apu_noise(info, &info->APU.noi);
      accum += apu_dpcm(info, &info->APU.dpcm);

      /* 8-bit clamps */
      if (accum > 127)
         accum = 127;
      else if (accum < -128)
         accum = -128;

      *(buffer16++)=accum<<8;
   }
}

/* READ VALUES FROM REGISTERS */
UINT8 nesapuRead(INT32 chip, INT32 address)
{
#if defined FBNEO_DEBUG
	if (!DebugSnd_NESAPUSndInitted) bprintf(PRINT_ERROR, _T("nesapuRead called without init\n"));
#endif

	struct nesapu_info *info = &nesapu_chips[chip];
	if (address == 0x0f) /*FIXED* Address $4015 has different behaviour*/
	{
		INT32 readval = 0;
		if (info->APU.squ[0].vbl_length > 0)
			readval |= 0x01;

		if (info->APU.squ[1].vbl_length > 0)
			readval |= 0x02;

		if (info->APU.tri.vbl_length > 0)
			readval |= 0x04;

		if (info->APU.noi.vbl_length > 0)
			readval |= 0x08;

		if (info->APU.dpcm.enabled == TRUE)
			readval |= 0x10;

		if (info->APU.dpcm.irq_occurred == TRUE)
			readval |= 0x80;

		return readval;
	} else {
		return info->APU.regs[address];
	}
}

/* WRITE VALUE TO TEMP REGISTRY AND QUEUE EVENT */
void nesapuWrite(INT32 chip, INT32 address, UINT8 value)
{
#if defined FBNEO_DEBUG
	if (!DebugSnd_NESAPUSndInitted) bprintf(PRINT_ERROR, _T("nesapuWrite called without init\n"));
#endif

	struct nesapu_info *info = &nesapu_chips[chip]; //sndti_token(SOUND_NES, chip);

	if (address > 0x17) return;

	info->APU.regs[address]=value;
	apu_update(info);
	apu_regwrite(info,address,value);
}

/* EXTERNAL INTERFACE FUNCTIONS */

/* UPDATE APU SYSTEM */
void nesapuUpdate(INT32 chip, INT16 *buf, INT32 samples)
{
#if defined FBNEO_DEBUG
	if (!DebugSnd_NESAPUSndInitted) bprintf(PRINT_ERROR, _T("nesapuUpdate called without init\n"));
#endif

	struct nesapu_info *info = &nesapu_chips[chip];

	if (pBurnSoundOut == NULL) {
		info->current_position = 0;
		return;
	}

	info->fill_buffer_hack = 1;
	apu_update(info);

	INT32 nAdd = info->bAdd;
	INT16 *stream = info->stream;

	UINT32 step = (info->samples_per_frame << 12) / nBurnSoundLen;
	INT32 pos = 0;

	for (INT32 i = 0; i < samples; i++) {
		if ((pos>>12) >= info->samples_per_frame) pos = (info->samples_per_frame-1) << 12;

		INT16 output = stream[pos>>12];

		/* write sound data to the buffer */
		INT32 nLeftSample = 0, nRightSample = 0;
			
		if ((info->output_dir[BURN_SND_NESAPU_ROUTE_1] & BURN_SND_ROUTE_LEFT) == BURN_SND_ROUTE_LEFT) {
			nLeftSample += (INT32)((output / 6) * info->gain[BURN_SND_NESAPU_ROUTE_1]);
		}
		if ((info->output_dir[BURN_SND_NESAPU_ROUTE_1] & BURN_SND_ROUTE_RIGHT) == BURN_SND_ROUTE_RIGHT) {
			nRightSample += (INT32)((output / 6) * info->gain[BURN_SND_NESAPU_ROUTE_1]);
		}
		if ((info->output_dir[BURN_SND_NESAPU_ROUTE_2] & BURN_SND_ROUTE_LEFT) == BURN_SND_ROUTE_LEFT) {
			nLeftSample += (INT32)((output / 6) * info->gain[BURN_SND_NESAPU_ROUTE_2]);
		}
		if ((info->output_dir[BURN_SND_NESAPU_ROUTE_2] & BURN_SND_ROUTE_RIGHT) == BURN_SND_ROUTE_RIGHT) {
			nRightSample += (INT32)((output / 6) * info->gain[BURN_SND_NESAPU_ROUTE_2]);
		}
		
		nLeftSample = BURN_SND_CLIP(nLeftSample);
		nRightSample = BURN_SND_CLIP(nRightSample);
		
		if (nAdd) {	
			buf[LEFT] += nLeftSample;
			buf[RIGHT] += nRightSample;
		} else {
			buf[LEFT] = nLeftSample;
			buf[RIGHT] = nRightSample;
		}

		buf += 2;
		pos += step;
	}

	info->current_position = 0;
	memset (info->stream, 0, info->samples_per_frame * sizeof(INT16));
}

void nesapuReset()
{
#if defined FBNEO_DEBUG
	if (!DebugSnd_NESAPUSndInitted) bprintf(PRINT_ERROR, _T("nesapuReset called without init\n"));
#endif

	for (INT32 i = 0; i < CHIP_NUM; i++) {
		struct nesapu_info *info = &nesapu_chips[i];

		info->current_position = 0;
		info->fill_buffer_hack = 0;

		for (INT32 j = 0; j < 2; j++)
		{
			for (INT32 k = 0; k < 4; k++) {
				info->APU.squ[j].regs[k] = 0;
			}
			info->APU.squ[j].vbl_length = 0;
			info->APU.squ[j].freq = 0;
			info->APU.squ[j].phaseacc = 0;
			info->APU.squ[j].output_vol = 0;
			info->APU.squ[j].env_phase = 0;
			info->APU.squ[j].sweep_phase = 0;
			info->APU.squ[j].adder = 0;
			info->APU.squ[j].env_vol = 0;
			info->APU.squ[j].enabled = 0;
		}

		for (INT32 k = 0; k < 4; k++) {
			info->APU.tri.regs[k] = 0;
		}
		info->APU.tri.linear_length = 0;
		info->APU.tri.vbl_length = 0;
		info->APU.tri.write_latency = 0;
		info->APU.tri.phaseacc = 0;
		info->APU.tri.output_vol = 0;
		info->APU.tri.adder = 0;
		info->APU.tri.counter_started = 0;
		info->APU.tri.enabled = 0;
		for (INT32 k = 0; k < 4; k++) {
			info->APU.noi.regs[k] = 0;
		}
		info->APU.noi.cur_pos = 0;
		info->APU.noi.vbl_length = 0;
		info->APU.noi.phaseacc = 0;
		info->APU.noi.output_vol = 0;
		info->APU.noi.env_phase = 0;
		info->APU.noi.env_vol = 0;
		info->APU.noi.enabled = 0;
		for (INT32 k = 0; k < 4; k++) {
			info->APU.dpcm.regs[k] = 0;
		}
		info->APU.dpcm.address = 0;
		info->APU.dpcm.length = 0;
		info->APU.dpcm.bits_left = 0;
		info->APU.dpcm.phaseacc = 0;
		info->APU.dpcm.output_vol = 0;
		info->APU.dpcm.cur_byte = 0;
		info->APU.dpcm.enabled = 0;
		info->APU.dpcm.irq_occurred = 0;
		info->APU.dpcm.vol = 0;
		for (INT32 k = 0; k < 17; k++) {
			info->APU.regs[k] = 0; 
		}
		info->APU.buf_pos = 0;
	}
}

/* INITIALIZE APU SYSTEM */
void nesapuInit(INT32 chip, INT32 clock, UINT32 (*pSyncCallback)(INT32 samples_per_frame), INT32 bAdd)
{
	DebugSnd_NESAPUSndInitted = 1;

	struct nesapu_info *info = &nesapu_chips[chip];
	INT32 rate = clock / 4;

	memset(info, 0, sizeof(nesapu_info));

	/* Initialize global variables */
	info->samps_per_sync = (rate * 100) / nBurnFPS;
	info->buffer_size = info->samps_per_sync;
	info->real_rate = (info->samps_per_sync * nBurnFPS) / 100;
	info->apu_incsize = (float) (clock / (float) info->real_rate);

	/* Use initializer calls */
	create_noise(info->noise_lut, 13, NOISE_LONG);
	create_vbltimes(info->vbl_times,vbl_length,info->samps_per_sync);
	create_syncs(info, info->samps_per_sync);

	/* Adjust buffer size if 16 bits */
	info->buffer_size+=info->samps_per_sync;

	info->samples_per_frame = (clock * 100) / 4 / nBurnFPS;

	info->pSyncCallback = pSyncCallback;

	info->bAdd = bAdd;

	info->stream = NULL;
	info->stream = (INT16*)BurnMalloc(info->samples_per_frame * 2 * sizeof(INT16));
	info->gain[BURN_SND_NESAPU_ROUTE_1] = 1.00;
	info->gain[BURN_SND_NESAPU_ROUTE_2] = 1.00;
	info->output_dir[BURN_SND_NESAPU_ROUTE_1] = BURN_SND_ROUTE_BOTH;
	info->output_dir[BURN_SND_NESAPU_ROUTE_2] = BURN_SND_ROUTE_BOTH;
}

void nesapuSetRoute(INT32 nChip, INT32 nIndex, double nVolume, INT32 nRouteDir)
{
#if defined FBNEO_DEBUG
	if (!DebugSnd_NESAPUSndInitted) bprintf(PRINT_ERROR, _T("nesapuSetRoute called without init\n"));
#endif

	struct nesapu_info *info = &nesapu_chips[nChip];
	
	info->gain[nIndex] = nVolume;
	info->output_dir[nIndex] = nRouteDir;
}

void nesapuExit()
{
#if defined FBNEO_DEBUG
	if (!DebugSnd_NESAPUSndInitted) bprintf(PRINT_ERROR, _T("nesapuExit called without init\n"));
#endif

	if (!DebugSnd_NESAPUSndInitted) return;

	struct nesapu_info *info;
	for (INT32 i = 0; i < CHIP_NUM; i++)
	{
		info = &nesapu_chips[i];
		if (info->stream)
			BurnFree(info->stream);
	}
	
	DebugSnd_NESAPUSndInitted = 0;
}

void nesapuScan(INT32 nAction, INT32 *)
{
#if defined FBNEO_DEBUG
	if (!DebugSnd_NESAPUSndInitted) bprintf(PRINT_ERROR, _T("nesapuScan called without init\n"));
#endif

	if (nAction & ACB_DRIVER_DATA)
	{
		for (INT32 i = 0; i < CHIP_NUM; i++)
		{
			struct nesapu_info *info = &nesapu_chips[i];

			SCAN_VAR(info->APU.squ);
			SCAN_VAR(info->APU.tri);
			SCAN_VAR(info->APU.noi);
			SCAN_VAR(info->APU.dpcm);
			SCAN_VAR(info->APU.regs);
			SCAN_VAR(info->APU.buf_pos);
		}
	}
}
