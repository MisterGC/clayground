/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
#include "svgwriter.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>

SvgWriter::SvgWriter()
{}

void SvgWriter::begin(float widthWu, float heightWu)
{
    QFile f("://clayground_internal/svgintro.txt");
    auto ok = f.open(QIODevice::ReadOnly);
    QTextStream str(&f);
    auto c = str.readAll()
            .arg(static_cast<double>(widthWu))
            .arg(static_cast<double>(heightWu));

    if (svgFile_.open(QIODevice::WriteOnly)) {
       QTextStream strOut(&svgFile_);
       strOut << c;
    }
    else
        qCritical() << "Cannot open file with path "
                    << svgFile_.fileName()
                    << svgFile_.errorString();
}

void SvgWriter::rectangle(const QString &/*description*/,
                          float /*x*/,
                          float /*y*/,
                          float /*width*/,
                          float /*height*/)
{
    // TODO
}

void SvgWriter::circle(const QString &/*description*/,
                       float /*x*/,
                       float /*y*/,
                       float /*radius*/)
{
    // TODO
}

void SvgWriter::end()
{
    QFile f("://clayground_internal/svgoutro.txt");
    f.open(QIODevice::ReadOnly);
    QTextStream str(&f);
    auto c = str.readAll();
    QTextStream strOut(&svgFile_);
    strOut << c;
    svgFile_.close();
}

void SvgWriter::setPath(const QString& pathToSvg)
{
    if (pathToSvg != pathToSvg_) {
        pathToSvg_ = pathToSvg;
        if (svgFile_.isOpen()) svgFile_.close();
        svgFile_.setFileName(pathToSvg_);
        emit pathChanged();
    }
}

QString SvgWriter::path() const
{
    return pathToSvg_;
}
