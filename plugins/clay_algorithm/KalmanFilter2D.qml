// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype KalmanFilter2D
    \inqmlmodule Clayground.Algorithm
    \brief Constant-velocity Kalman filter for 2D position tracking.

    State [x, y, vx, vy]. Call predict(dt) on a fixed tick and
    correct(zx, zy, sigma) for every position measurement from any
    sensor; sigma is that sensor's standard deviation, which is how
    fusion weighs sources by their uncertainty.

    Example usage:
    \qml
    import Clayground.Algorithm

    KalmanFilter2D { id: kf; processNoise: 0.8 }
    // per tick: kf.predict(dt)
    // per fix:  kf.correct(fix.x, fix.y, 3.0)
    \endqml
*/
QtObject {
    id: _kf

    /*!
        \qmlproperty real KalmanFilter2D::processNoise
        \brief Acceleration standard deviation of the motion model.
    */
    property real processNoise: 0.8

    /*!
        \qmlproperty real KalmanFilter2D::estX
        \readonly
        \brief Estimated x position.
    */
    property real estX: 0

    /*!
        \qmlproperty real KalmanFilter2D::estY
        \readonly
        \brief Estimated y position.
    */
    property real estY: 0

    /*!
        \qmlproperty real KalmanFilter2D::sigmaX
        \readonly
        \brief Position uncertainty (std dev) along x.
    */
    property real sigmaX: 5

    /*!
        \qmlproperty real KalmanFilter2D::sigmaY
        \readonly
        \brief Position uncertainty (std dev) along y.
    */
    property real sigmaY: 5

    property var _x: [0, 0, 0, 0]
    property var _P: [[25, 0, 0, 0], [0, 25, 0, 0], [0, 0, 4, 0], [0, 0, 0, 4]]

    function _publish() {
        estX = _x[0]; estY = _x[1]
        sigmaX = Math.sqrt(Math.max(0, _P[0][0]))
        sigmaY = Math.sqrt(Math.max(0, _P[1][1]))
    }

    /*!
        \qmlmethod void KalmanFilter2D::reset(real px, real py)
        \brief Re-initializes the state at a position with high uncertainty.
    */
    function reset(px, py) {
        _x = [px, py, 0, 0]
        _P = [[25, 0, 0, 0], [0, 25, 0, 0], [0, 0, 4, 0], [0, 0, 0, 4]]
        _publish()
    }

    /*!
        \qmlmethod void KalmanFilter2D::predict(real dt)
        \brief Advances the state by dt using the constant-velocity model.
    */
    function predict(dt) {
        const x = _x, P = _P
        _x = [x[0] + dt * x[2], x[1] + dt * x[3], x[2], x[3]]
        // F P F^T for F = [[1,0,dt,0],[0,1,0,dt],[0,0,1,0],[0,0,0,1]]
        const FP = [
            [P[0][0] + dt * P[2][0], P[0][1] + dt * P[2][1], P[0][2] + dt * P[2][2], P[0][3] + dt * P[2][3]],
            [P[1][0] + dt * P[3][0], P[1][1] + dt * P[3][1], P[1][2] + dt * P[3][2], P[1][3] + dt * P[3][3]],
            P[2].slice(), P[3].slice()
        ]
        const N = [
            [FP[0][0] + dt * FP[0][2], FP[0][1] + dt * FP[0][3], FP[0][2], FP[0][3]],
            [FP[1][0] + dt * FP[1][2], FP[1][1] + dt * FP[1][3], FP[1][2], FP[1][3]],
            [FP[2][0] + dt * FP[2][2], FP[2][1] + dt * FP[2][3], FP[2][2], FP[2][3]],
            [FP[3][0] + dt * FP[3][2], FP[3][1] + dt * FP[3][3], FP[3][2], FP[3][3]]
        ]
        // Q: piecewise-constant acceleration
        const q = processNoise * processNoise
        const d2 = dt * dt
        N[0][0] += 0.25 * d2 * d2 * q; N[1][1] += 0.25 * d2 * d2 * q
        N[0][2] += 0.5 * d2 * dt * q; N[2][0] += 0.5 * d2 * dt * q
        N[1][3] += 0.5 * d2 * dt * q; N[3][1] += 0.5 * d2 * dt * q
        N[2][2] += d2 * q; N[3][3] += d2 * q
        _P = N
        _publish()
    }

    /*!
        \qmlmethod void KalmanFilter2D::correct(real zx, real zy, real sigma)
        \brief Fuses a position measurement with standard deviation sigma.
    */
    function correct(zx, zy, sigma) {
        const x = _x, P = _P
        const r = sigma * sigma
        // S = H P H^T + R (2x2), H = [[1,0,0,0],[0,1,0,0]]
        const s00 = P[0][0] + r, s01 = P[0][1], s10 = P[1][0], s11 = P[1][1] + r
        const det = s00 * s11 - s01 * s10
        if (Math.abs(det) < 1e-12) return
        const i00 = s11 / det, i01 = -s01 / det, i10 = -s10 / det, i11 = s00 / det
        // K = P H^T S^-1 (4x2)
        const K = []
        for (let i = 0; i < 4; ++i)
            K.push([P[i][0] * i00 + P[i][1] * i10, P[i][0] * i01 + P[i][1] * i11])
        const yx = zx - x[0], yy = zy - x[1]
        _x = [x[0] + K[0][0] * yx + K[0][1] * yy,
              x[1] + K[1][0] * yx + K[1][1] * yy,
              x[2] + K[2][0] * yx + K[2][1] * yy,
              x[3] + K[3][0] * yx + K[3][1] * yy]
        // P = (I - K H) P
        const N = []
        for (let i = 0; i < 4; ++i) {
            N.push([])
            for (let j = 0; j < 4; ++j)
                N[i].push(P[i][j] - K[i][0] * P[0][j] - K[i][1] * P[1][j])
        }
        _P = N
        _publish()
    }
}
