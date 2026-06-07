#!/usr/bin/env python3

import json
import statistics
import time
import urllib.parse
import urllib.request

# ============================================================================
# Qidi Q2 Fan Kickstart Calibration Script
# ============================================================================

BASE = "your.ip.adress:7125"
FAN_NAME = "cooling_fan"

SAMPLE_DT = 0.04

RPM_NOISE_FLOOR = 50
ROLLING_WINDOW = 5

STABILITY_WINDOW = 0.5
STABILITY_PERCENT = 0.02

INITIAL_POST_TIME = 4.0
MAX_POST_TIME = 10.0

HTTP_RETRIES = 5
HTTP_TIMEOUT = 10


# ============================================================================
# Moonraker helpers
# ============================================================================

def send_gcode(command, critical=False):
    """
    Send G-code through Moonraker.

    critical=True:
        Raise exception if all retries fail.

    critical=False:
        Log warning and continue.
    """

    url = (
        f"{BASE}/printer/gcode/script?"
        f"script={urllib.parse.quote(command)}"
    )

    last_error = None

    for attempt in range(HTTP_RETRIES):

        try:
            urllib.request.urlopen(
                url,
                timeout=HTTP_TIMEOUT
            ).read()

            return True

        except Exception as e:

            last_error = e

            print(
                f"[WARN] G-code send failed "
                f"(attempt {attempt + 1}/{HTTP_RETRIES})"
            )

            time.sleep(0.5)

    print(f"[ERROR] Failed command: {command}")
    print(f"[ERROR] {last_error}")

    if critical:
        raise last_error

    return False


def get_rpm():
    """
    Read fan RPM from Moonraker.

    Returns:
        RPM value or None on failure.
    """

    url = (
        f"{BASE}/printer/objects/query?"
        f"fan_generic%20{FAN_NAME}"
    )

    for attempt in range(HTTP_RETRIES):

        try:

            data = json.loads(
                urllib.request.urlopen(
                    url,
                    timeout=HTTP_TIMEOUT
                ).read()
            )

            return data["result"]["status"][
                f"fan_generic {FAN_NAME}"
            ]["rpm"]

        except Exception:

            time.sleep(0.2)

    return None


# ============================================================================
# RPM processing helpers
# ============================================================================

def rolling_average(values, window):

    output = []

    for i in range(len(values)):

        start = max(0, i - window + 1)

        subset = values[start:i + 1]

        output.append(
            sum(subset) / len(subset)
        )

    return output


def is_stable(samples):
    """
    Detect whether RPM has stabilized.

    Prevents false readings while fan
    is still decelerating from kickstart.
    """

    if len(samples) < 5:
        return False

    latest_time = samples[-1][0]

    recent = [
        rpm for t, rpm in samples
        if latest_time - t <= STABILITY_WINDOW
    ]

    if len(recent) < 3:
        return False

    avg = statistics.mean(recent)

    if avg <= 0:
        return False

    variation = max(recent) - min(recent)

    return (
        variation / avg
    ) < STABILITY_PERCENT


# ============================================================================
# Main test routine
# ============================================================================

def run_combo(kick_s, target_pct, settle=3.0):

    target = target_pct / 100.0

    # Stop fan completely
    send_gcode(
        f"SET_FAN_SPEED FAN={FAN_NAME} SPEED=0"
    )

    time.sleep(settle)

    # Flush stale RPM read
    get_rpm()

    # Kickstart phase
    if kick_s > 0:

        send_gcode(
            f"SET_FAN_SPEED FAN={FAN_NAME} SPEED=1.0"
        )

        time.sleep(kick_s)

    start_time = time.perf_counter()

    # Apply target speed
    send_gcode(
        f"SET_FAN_SPEED FAN={FAN_NAME} SPEED={target}"
    )

    samples = []

    while True:

        elapsed = (
            time.perf_counter() - start_time
        )

        rpm = get_rpm()

        if rpm is not None:
            samples.append((elapsed, rpm))

        # Allow stabilization detection
        if elapsed >= INITIAL_POST_TIME:

            if is_stable(samples):
                break

        # Hard timeout
        if elapsed >= MAX_POST_TIME:

            print(
                "[WARN] Stability timeout reached"
            )

            break

        time.sleep(SAMPLE_DT)

    # Fallback protection
    if not samples:

        return (
            0,
            None,
            None,
            None,
        )

    times = [t for t, r in samples]
    rpms = [r for t, r in samples]

    smooth_rpms = rolling_average(
        rpms,
        ROLLING_WINDOW
    )

    stable_region = [
        rpm for t, rpm in zip(times, smooth_rpms)
        if times[-1] - t <= STABILITY_WINDOW
    ]

    if stable_region:
        stable_rpm = statistics.mean(
            stable_region
        )
    else:
        stable_rpm = smooth_rpms[-1]

    rpm_90 = stable_rpm * 0.9

    t90 = next(
        (
            t for t, rpm in zip(
                times,
                smooth_rpms
            )
            if rpm >= rpm_90
        ),
        None
    )

    first_nonzero = next(
        (
            t for t, rpm in zip(
                times,
                smooth_rpms
            )
            if rpm > RPM_NOISE_FLOOR
        ),
        None
    )

    settle_time = times[-1]

    return (
        stable_rpm,
        t90,
        first_nonzero,
        settle_time,
    )


# ============================================================================
# Main sweep
# ============================================================================

def main():

    print(f"# Testing against {BASE}")
    print("# Targets: 20% and 40%")
    print()

    print(
        f"{'target':>6} "
        f"{'kick_s':>6} "
        f"{'trial':>5} "
        f"{'stable':>7} "
        f"{'first_nz':>9} "
        f"{'t90':>7} "
        f"{'settle':>8}"
    )

    kicks = [
        0.0,
        0.3,
        0.5,
        0.8,
        1.0,
        1.5,
        2.0,
    ]

    targets = [20, 40]

    results = []

    for target_pct in targets:

        for kick_s in kicks:

            for trial in (1, 2):

                try:

                    (
                        stable_rpm,
                        t90,
                        first_nonzero,
                        settle_time,
                    ) = run_combo(
                        kick_s,
                        target_pct
                    )

                except Exception as e:

                    print(
                        f"[ERROR] Test failed: "
                        f"{target_pct}% "
                        f"{kick_s:.2f}s"
                    )

                    print(e)

                    continue

                results.append(
                    (
                        target_pct,
                        kick_s,
                        stable_rpm,
                        first_nonzero,
                        t90,
                        settle_time,
                    )
                )

                fnz_s = (
                    f"{first_nonzero * 1000:.0f}ms"
                    if first_nonzero is not None
                    else "n/a"
                )

                t90_s = (
                    f"{t90 * 1000:.0f}ms"
                    if t90 is not None
                    else "n/a"
                )

                settle_s = (
                    f"{settle_time * 1000:.0f}ms"
                    if settle_time is not None
                    else "n/a"
                )

                print(
                    f"{target_pct:>5}% "
                    f"{kick_s:>6.2f} "
                    f"{trial:>5} "
                    f"{stable_rpm:>7.0f} "
                    f"{fnz_s:>9} "
                    f"{t90_s:>7} "
                    f"{settle_s:>8}"
                )

    # Stop fan
    send_gcode(
        f"SET_FAN_SPEED FAN={FAN_NAME} SPEED=0"
    )

    # =========================================================================
    # Recommendations
    # =========================================================================

    print()
    print("# Recommended Settings")

    recommendations = []

    for target_pct in targets:

        valid = [
            r for r in results
            if r[0] == target_pct
        ]

        scored = []

        for row in valid:

            (
                tp,
                kick_s,
                stable_rpm,
                first_nonzero,
                t90,
                settle_time,
            ) = row

            if (
                first_nonzero is None or
                t90 is None or
                settle_time is None
            ):
                continue

            score = (
                first_nonzero * 0.4 +
                t90 * 0.4 +
                settle_time * 0.2
            )

            scored.append(
                (
                    score,
                    kick_s,
                    stable_rpm,
                    first_nonzero,
                    t90,
                    settle_time,
                )
            )

        if not scored:
            continue

        best = min(
            scored,
            key=lambda x: x[0]
        )

        (
            score,
            best_kick,
            stable_rpm,
            first_nonzero,
            t90,
            settle_time,
        ) = best

        recommendations.append(best_kick)

        print()
        print(f"Target {target_pct}%")
        print(
            f"  Recommended kickstart: "
            f"{best_kick:.2f}s"
        )

    if recommendations:

        avg_kick = (
            sum(recommendations)
            / len(recommendations)
        )

        suggested_kickdown = max(
            0.10,
            avg_kick * 0.5
        )

        print()
        print("# Suggested Orca Values")
        print(
            f"kick_start_time = "
            f"{avg_kick:.2f}"
        )
        print(
            f"kick_down_time  = "
            f"{suggested_kickdown:.2f}"
        )

    print()
    print("# Complete")


if __name__ == "__main__":
    main()
