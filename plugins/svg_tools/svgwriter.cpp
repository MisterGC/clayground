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
#include <simple-svg-writer/simple_svg.h>
#include <QFile>
#include <QTextStream>
#include <QDebug>

class SvgWriter::SvgWriterImpl
{
    // TODO
};

SvgWriter::SvgWriter() : impl_(new SvgWriterImpl)
{}

SvgWriter::~SvgWriter() = default;

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

void SvgWriter::rectangle(const QString& id,
                          const QString &description,
                          float x,
                          float y,
                          float width,
                          float height)
{
    auto rect = QString(R"(
<rect
    x="%1"
    y="%2"
    width="%3"
    height="%4"
    id="%5"
    style="opacity:1;
           fill:#cccccc;
           fill-opacity:1;
           stroke:none;
           stroke-width:0.62179309;
           stroke-miterlimit:4;
           stroke-dasharray:none;
           stroke-dashoffset:0;
           stroke-opacity:1">
    <desc>%6</desc>
</rect>
)")
            .arg(static_cast<double>(x))
            .arg(static_cast<double>(y))
            .arg(static_cast<double>(width))
            .arg(static_cast<double>(height))
            .arg(id)
            .arg(description.toHtmlEscaped());

    QTextStream strOut(&svgFile_);
    strOut << rect;
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
