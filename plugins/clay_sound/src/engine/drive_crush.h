// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Drive and crush (#452): what a voice does to its own signal after its
// envelope and before its velocity, so a layer's gain stays its output
// level and does not change how hard it is driven.
//
// Drive saturates: tanh of the signal raised by driveDb. Odd harmonics
// grow with it, and the peaks stay inside -1..1; 0 dB is a plain soft
// clip, which already rounds a full-scale peak to 0.76.
//
// Crush is a chip's grit. crushRate holds each value for one period of
// that rate, as a lower sample rate would, and crushBits rounds every
// value to a step of 2^(1 - bits) of full scale. Both are read as
// continuous numbers, so a knob between two bit depths moves smoothly.

#pragma once

#include <cmath>

namespace clay::sound {

struct DriveCrush
{
    // Off, the default, leaves the signal as it was without drive.
    bool   drive   = false;
    double driveDb = 0.0;

    // 0, the default, is no rounding; 1..24 bits round.
    double crushBits = 0.0;
    // 0, the default, or a rate at or above the voice's sample rate holds
    // nothing; anything lower holds each value 1/crushRate seconds.
    double crushRate = 0.0;

    bool active() const { return drive || crushBits > 0.0 || crushRate > 0.0; }
};

// One voice's drive and crush: the settings turned into factors once per
// note, and the value a rate crush holds.
class DriveCrushState
{
public:
    void start(const DriveCrush &d, int sampleRate)
    {
        active_ = d.active();
        drive_  = d.drive ? std::pow(10.0, d.driveDb / 20.0) : 0.0;
        steps_  = d.crushBits > 0.0 ? std::pow(2.0, d.crushBits - 1.0) : 0.0;
        hold_   = d.crushRate > 0.0 && d.crushRate < sampleRate ? d.crushRate / sampleRate : 0.0;
        // Starts full, so the first sample is taken, not a held 0.
        phase_  = 1.0;
        held_   = 0.0;
    }

    double process(double x)
    {
        if (!active_) return x;
        if (drive_ > 0.0) x = std::tanh(drive_ * x);
        if (hold_ > 0.0) {
            if (phase_ >= 1.0) {
                phase_ -= std::floor(phase_);
                held_ = x;
            }
            x = held_;
            phase_ += hold_;
        }
        if (steps_ > 0.0) x = std::round(x * steps_) / steps_;
        return x;
    }

private:
    bool   active_ = false;
    double drive_  = 0.0;   // linear gain into tanh; 0 = no drive
    double steps_  = 0.0;   // rounding steps per unit; 0 = no rounding
    double hold_   = 0.0;   // crushRate / sample rate; 0 = no hold
    double phase_  = 1.0;
    double held_   = 0.0;
};

} // namespace clay::sound
